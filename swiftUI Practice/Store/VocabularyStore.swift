import Foundation
import SwiftUI
import AVFoundation

// MARK: - 词汇中央数据仓库
class VocabularyStore: ObservableObject {
    @Published var wordBooks: [WordBook] = []
    @Published var wordRecords: [WordRecord] = []
    @Published var dailyWords: [Word] = []
    @Published var loadingBookId: UUID? = nil   // 启用内置词库时的加载状态

    private var lastDailyDate: Date?

    // UserDefaults 存储键（与 VocabSharedHelper 保持一致）
    enum Keys {
        static let books           = "vocab_books_v1"        // 用户自建/导入词库
        static let records         = "vocab_records_v1"
        static let daily           = "vocab_daily_v1"
        static let dailyDate       = "vocab_daily_date_v1"
        static let builtInEnabled  = "vocab_builtin_enabled_v1"  // 已启用内置词库 ID 列表
        static let totalCount      = "vocab_total_count_v1"      // 缓存总词数（供 Widget 读取）
    }

    // MARK: 计算属性
    var allWords: [Word] {
        wordBooks.filter { $0.isEnabled }.flatMap { $0.words }
    }

    var dueWords: [Word] {
        let dueIds = Set(wordRecords.filter { $0.isDue }.map { $0.wordId })
        return allWords.filter { dueIds.contains($0.id) }
            .sorted { w1, w2 in
                let p1 = wordRecords.first { $0.wordId == w1.id }.map { r in
                    Double(r.studyCount) + (r.correctStreak == 0 ? 3 : 0)
                } ?? 0
                let p2 = wordRecords.first { $0.wordId == w2.id }.map { r in
                    Double(r.studyCount) + (r.correctStreak == 0 ? 3 : 0)
                } ?? 0
                return p1 > p2
            }
    }

    var masteredWords: [Word] {
        let masteredIds = Set(wordRecords.filter { $0.isMastered }.map { $0.wordId })
        return allWords.filter { masteredIds.contains($0.id) }
    }

    var dueCount: Int { dueWords.count }
    var masteredCount: Int { masteredWords.count }

    // 便于视图区分内置 / 用户词库
    var builtInWordBooks: [WordBook] { wordBooks.filter { $0.isBuiltIn } }
    var userWordBooks: [WordBook]    { wordBooks.filter { !$0.isBuiltIn } }

    // MARK: 初始化
    init() {
        load()
        refreshDailyIfNeeded()
    }

    // MARK: 每日单词（最多 15 个到期 + 补充新词至 20）
    func generateDailyWords() {
        var result = Array(dueWords.prefix(15))
        let studiedIds = Set(wordRecords.map { $0.wordId })
        let newWords = allWords.filter { !studiedIds.contains($0.id) }.shuffled()
        let needed = max(0, 20 - result.count)
        result += Array(newWords.prefix(needed))
        dailyWords = result
        lastDailyDate = Date()
        saveDailyCache()
    }

    func refreshDailyIfNeeded() {
        guard let last = lastDailyDate else { generateDailyWords(); return }
        if !Calendar.current.isDateInToday(last) { generateDailyWords() }
    }

    // MARK: 学习记录更新
    func recordStudy(wordId: UUID, isCorrect: Bool) {
        if let idx = wordRecords.firstIndex(where: { $0.wordId == wordId }) {
            wordRecords[idx].update(isCorrect: isCorrect)
        } else {
            var record = WordRecord(wordId: wordId)
            record.update(isCorrect: isCorrect)
            wordRecords.append(record)
        }
        save()
    }

    func wordRecord(for wordId: UUID) -> WordRecord? {
        wordRecords.first { $0.wordId == wordId }
    }

    func toggleMastered(_ wordId: UUID) {
        if let idx = wordRecords.firstIndex(where: { $0.wordId == wordId }) {
            wordRecords[idx].isMastered.toggle()
        } else {
            var record = WordRecord(wordId: wordId)
            record.isMastered = true
            wordRecords.append(record)
        }
        save()
    }

    // MARK: 内置词库启用 / 禁用（异步加载）
    func toggleBuiltInBook(_ bookId: UUID) {
        guard let idx = wordBooks.firstIndex(where: { $0.id == bookId && $0.isBuiltIn }) else { return }
        let willEnable = !wordBooks[idx].isEnabled

        if willEnable {
            guard let meta = BuiltInWordBooks.catalog.first(where: { $0.id == bookId }) else { return }
            loadingBookId = bookId
            Task {
                let words = await Task.detached(priority: .userInitiated) {
                    BuiltInWordBooks.loadWords(for: meta)
                }.value
                await MainActor.run {
                    if let i = self.wordBooks.firstIndex(where: { $0.id == bookId }) {
                        self.wordBooks[i].words = words
                        self.wordBooks[i].isEnabled = true
                    }
                    self.loadingBookId = nil
                    self.refreshDailyIfNeeded()
                    self.save()
                }
            }
        } else {
            wordBooks[idx].words = []       // 释放内存
            wordBooks[idx].isEnabled = false
            save()
        }
    }

    // MARK: 用户词库管理
    func addWordBook(_ book: WordBook) {
        wordBooks.append(book)
        save()
    }

    func deleteWordBook(_ book: WordBook) {
        guard !book.isBuiltIn else { return }
        wordBooks.removeAll { $0.id == book.id }
        save()
    }

    func addWord(_ word: Word, to bookId: UUID) {
        guard let idx = wordBooks.firstIndex(where: { $0.id == bookId }) else { return }
        wordBooks[idx].words.append(word)
        save()
    }

    func importWordBook(from data: Data) throws {
        let decoder = JSONDecoder()
        let bookImport = try decoder.decode(WordBookImport.self, from: data)
        let book = bookImport.toWordBook()
        wordBooks.append(book)
        refreshDailyIfNeeded()
        save()
    }

    func deleteWord(_ wordId: UUID, from bookId: UUID) {
        guard let bi = wordBooks.firstIndex(where: { $0.id == bookId }) else { return }
        wordBooks[bi].words.removeAll { $0.id == wordId }
        wordRecords.removeAll { $0.wordId == wordId }
        save()
    }

    // MARK: TTS 发音
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
    }

    // MARK: 快速添加生词（供 Siri / Widget 调用）
    @discardableResult
    func quickAddWord(_ wordString: String) -> Bool {
        let lower = wordString.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lower.isEmpty else { return false }

        if allWords.contains(where: { $0.word.lowercased() == lower }) { return false }

        let word = Word(
            word: wordString.trimmingCharacters(in: .whitespaces),
            phonetic: "",
            partOfSpeech: "n.",
            definitions: [Word.Definition(meaning: "（待补充释义）", exampleEn: nil, exampleZh: nil)],
            source: .manual
        )

        if let idx = wordBooks.firstIndex(where: { $0.name == "我的生词本" && !$0.isBuiltIn }) {
            wordBooks[idx].words.append(word)
        } else {
            var myBook = WordBook(name: "我的生词本", level: "自定义", description: "通过 Siri / Widget 快速添加的生词")
            myBook.words.append(word)
            wordBooks.append(myBook)
        }
        save()
        return true
    }

    // MARK: 持久化
    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // 只保存用户词库，内置词库从 Bundle 读取，不存入 UserDefaults
        let userBooks = wordBooks.filter { !BuiltInWordBooks.isBuiltIn($0.id) }
        if let data = try? encoder.encode(userBooks) {
            UserDefaults.shared.set(data, forKey: Keys.books)
        }

        // 保存已启用的内置词库 ID（仅存 ID，不存单词）
        let enabledIds = wordBooks
            .filter { BuiltInWordBooks.isBuiltIn($0.id) && $0.isEnabled }
            .map { $0.id.uuidString }
        UserDefaults.shared.set(enabledIds, forKey: Keys.builtInEnabled)

        // 缓存总词数供 Widget 读取
        UserDefaults.shared.set(allWords.count, forKey: Keys.totalCount)

        if let data = try? encoder.encode(wordRecords) {
            UserDefaults.shared.set(data, forKey: Keys.records)
        }
    }

    private func saveDailyCache() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(dailyWords) {
            UserDefaults.shared.set(data, forKey: Keys.daily)
        }
        if let date = lastDailyDate {
            UserDefaults.shared.set(date, forKey: Keys.dailyDate)
        }
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 加载用户词库
        var userBooks: [WordBook] = []
        if let data = UserDefaults.shared.data(forKey: Keys.books),
           let books = try? decoder.decode([WordBook].self, from: data) {
            // 过滤掉旧版可能误存的内置词库数据
            userBooks = books.filter { !BuiltInWordBooks.isBuiltIn($0.id) }
        }

        // 加载内置词库（已启用的从 Bundle 读取单词，未启用的只建立存根）
        let enabledIds = Set(
            (UserDefaults.shared.array(forKey: Keys.builtInEnabled) as? [String] ?? [])
                .compactMap { UUID(uuidString: $0) }
        )
        let builtInBooks = BuiltInWordBooks.catalog.map { meta -> WordBook in
            let isEnabled = enabledIds.contains(meta.id)
            let words: [Word] = isEnabled ? BuiltInWordBooks.loadWords(for: meta) : []
            return WordBook(
                id: meta.id,
                name: meta.name,
                level: meta.level,
                description: meta.description,
                words: words,
                isBuiltIn: true,
                isEnabled: isEnabled
            )
        }

        wordBooks = builtInBooks + userBooks

        // 加载记录和每日缓存
        if let data = UserDefaults.shared.data(forKey: Keys.records),
           let records = try? decoder.decode([WordRecord].self, from: data) {
            wordRecords = records
        }
        if let data = UserDefaults.shared.data(forKey: Keys.daily),
           let words = try? decoder.decode([Word].self, from: data) {
            dailyWords = words
        }
        lastDailyDate = UserDefaults.shared.object(forKey: Keys.dailyDate) as? Date
    }
}
