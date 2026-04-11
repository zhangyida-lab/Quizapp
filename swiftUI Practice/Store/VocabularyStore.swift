import Foundation
import SwiftUI
import AVFoundation

// MARK: - 启用词库后的匹配同步提案
struct EnrichmentProposal: Identifiable {
    let id = UUID()
    let bookName: String      // 刚启用的内置词库名
    let bookId: UUID
    let matchCount: Int       // 生词本中可同步的单词数
}

// MARK: - 词汇中央数据仓库
class VocabularyStore: ObservableObject {
    @Published var wordBooks: [WordBook] = []
    @Published var wordRecords: [WordRecord] = []
    @Published var dailyWords: [Word] = []
    @Published var loadingBookId: UUID? = nil       // 启用内置词库时的加载状态
    @Published var enrichmentProposal: EnrichmentProposal? = nil  // 待确认的同步提案

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

    var studiedWords: [Word] {
        let studiedIds = Set(wordRecords.map { $0.wordId })
        return allWords.filter { studiedIds.contains($0.id) }
    }

    var dueCount: Int { dueWords.count }
    var masteredCount: Int { masteredWords.count }

    // 便于视图区分内置 / 用户词库
    var builtInWordBooks: [WordBook] { wordBooks.filter { $0.isBuiltIn } }
    var userWordBooks: [WordBook]    { wordBooks.filter { !$0.isBuiltIn } }

    // MARK: 初始化
    init() {
        load()
        enrichPendingWords()
        refreshDailyIfNeeded()
    }

    // 从后台回到前台时调用，确保 Siri/Widget 写入的数据同步到内存
    func reload() {
        load()
        enrichPendingWords()
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
                    // 检查用户生词本中有多少词可以从本词库同步
                    self.checkEnrichmentProposal(for: bookId, bookWords: words)
                }
            }
        } else {
            wordBooks[idx].words = []       // 释放内存
            wordBooks[idx].isEnabled = false
            save()
        }
    }

    // MARK: 手动添加单词
    enum AddWordResult {
        case enriched   // 在内置词库找到，已补全释义
        case added      // 未找到，以"待补充释义"添加
        case duplicate  // 单词已存在
    }

    @discardableResult
    func quickAddManual(word: String) -> AddWordResult {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .duplicate }
        let lower = trimmed.lowercased()

        // 已存在则跳过
        let exists = wordBooks.filter { !$0.isBuiltIn }.flatMap { $0.words }
            .contains { $0.word.lowercased() == lower }
        if exists { return .duplicate }

        // 优先从已启用内置词库匹配
        let builtInWords = wordBooks.filter { $0.isBuiltIn && $0.isEnabled }.flatMap { $0.words }
        if let match = builtInWords.first(where: { $0.word.lowercased() == lower }) {
            var newWord = match
            newWord.id = UUID()
            newWord.source = .manual
            newWord.createdAt = Date()
            addToMyNotebook(newWord)
            return .enriched
        }

        let newWord = Word(
            word: trimmed, phonetic: "", partOfSpeech: "n.",
            definitions: [Word.Definition(meaning: "（待补充释义）", exampleEn: nil, exampleZh: nil)],
            source: .manual
        )
        addToMyNotebook(newWord)
        return .added
    }

    // 在内置词库中查询单词预览（用于手动添加时的实时提示）
    func lookupInBuiltIn(word: String) -> Word? {
        let lower = word.lowercased()
        return wordBooks.filter { $0.isBuiltIn && $0.isEnabled }.flatMap { $0.words }
            .first { $0.word.lowercased() == lower }
    }

    private func addToMyNotebook(_ word: Word) {
        if let idx = wordBooks.firstIndex(where: { $0.name == "我的生词本" && !$0.isBuiltIn }) {
            wordBooks[idx].words.append(word)
        } else {
            var book = WordBook(name: "我的生词本", level: "自定义", description: "手动添加的生词")
            book.words.append(word)
            wordBooks.append(book)
        }
        save()
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

    func updateWord(_ word: Word) {
        for bi in wordBooks.indices {
            if let wi = wordBooks[bi].words.firstIndex(where: { $0.id == word.id }) {
                wordBooks[bi].words[wi] = word
                save()
                return
            }
        }
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

    // 检测刚启用的词库与用户生词本的匹配数，有则生成同步提案
    private func checkEnrichmentProposal(for bookId: UUID, bookWords: [Word]) {
        let bookWordMap = Dictionary(
            bookWords.map { ($0.word.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let userWords = wordBooks.filter { !$0.isBuiltIn }.flatMap { $0.words }
        let matchCount = userWords.filter { bookWordMap[$0.word.lowercased()] != nil }.count
        guard matchCount > 0 else { return }

        let bookName = wordBooks.first { $0.id == bookId }?.name ?? "内置词库"
        enrichmentProposal = EnrichmentProposal(
            bookName: bookName,
            bookId: bookId,
            matchCount: matchCount
        )
    }

    // 用指定内置词库的内容同步用户生词本中匹配的单词
    func applyEnrichment(from bookId: UUID) {
        let bookWords = wordBooks.first { $0.id == bookId }?.words ?? []
        let bookWordMap = Dictionary(
            bookWords.map { ($0.word.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var changed = false
        for bi in wordBooks.indices {
            guard !wordBooks[bi].isBuiltIn else { continue }
            for wi in wordBooks[bi].words.indices {
                let w = wordBooks[bi].words[wi]
                if let match = bookWordMap[w.word.lowercased()] {
                    wordBooks[bi].words[wi].phonetic     = match.phonetic
                    wordBooks[bi].words[wi].partOfSpeech = match.partOfSpeech
                    wordBooks[bi].words[wi].definitions  = match.definitions
                    changed = true
                }
            }
        }
        if changed { save() }
        enrichmentProposal = nil
    }

    // 自动补全释义：对用户词库中标记为"待补充释义"的单词，
    // 在已启用的内置词库里查找同名词并复制其释义/音标/词性
    private func enrichPendingWords() {
        let builtInWords = wordBooks
            .filter { $0.isBuiltIn && $0.isEnabled }
            .flatMap { $0.words }
        guard !builtInWords.isEmpty else { return }

        var changed = false
        for bi in wordBooks.indices {
            guard !wordBooks[bi].isBuiltIn else { continue }
            for wi in wordBooks[bi].words.indices {
                let w = wordBooks[bi].words[wi]
                guard w.definitions.first?.meaning == "（待补充释义）" else { continue }
                if let match = builtInWords.first(where: {
                    $0.word.lowercased() == w.word.lowercased()
                }) {
                    wordBooks[bi].words[wi].phonetic     = match.phonetic
                    wordBooks[bi].words[wi].partOfSpeech = match.partOfSpeech
                    wordBooks[bi].words[wi].definitions  = match.definitions
                    changed = true
                }
            }
        }
        if changed { save() }
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
