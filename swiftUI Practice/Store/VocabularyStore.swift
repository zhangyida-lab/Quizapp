import Foundation
import SwiftUI
import AVFoundation

// MARK: - 词汇中央数据仓库
class VocabularyStore: ObservableObject {
    @Published var wordBooks: [WordBook] = []
    @Published var wordRecords: [WordRecord] = []
    @Published var dailyWords: [Word] = []

    private var lastDailyDate: Date?

    // UserDefaults 存储键
    private enum Keys {
        static let books      = "vocab_books_v1"
        static let records    = "vocab_records_v1"
        static let daily      = "vocab_daily_v1"
        static let dailyDate  = "vocab_daily_date_v1"
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

    // MARK: 初始化
    init() {
        load()
        ensureBuiltInWordBook()
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

    // MARK: 词库管理
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

    // MARK: 持久化
    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(wordBooks) {
            UserDefaults.standard.set(data, forKey: Keys.books)
        }
        if let data = try? encoder.encode(wordRecords) {
            UserDefaults.standard.set(data, forKey: Keys.records)
        }
    }

    private func saveDailyCache() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(dailyWords) {
            UserDefaults.standard.set(data, forKey: Keys.daily)
        }
        if let date = lastDailyDate {
            UserDefaults.standard.set(date, forKey: Keys.dailyDate)
        }
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: Keys.books),
           let books = try? decoder.decode([WordBook].self, from: data) {
            wordBooks = books
        }
        if let data = UserDefaults.standard.data(forKey: Keys.records),
           let records = try? decoder.decode([WordRecord].self, from: data) {
            wordRecords = records
        }
        if let data = UserDefaults.standard.data(forKey: Keys.daily),
           let words = try? decoder.decode([Word].self, from: data) {
            dailyWords = words
        }
        lastDailyDate = UserDefaults.standard.object(forKey: Keys.dailyDate) as? Date
    }

    private func ensureBuiltInWordBook() {
        if !wordBooks.contains(where: { $0.id == BuiltInWords.bookId }) {
            wordBooks.insert(BuiltInWords.wordBook, at: 0)
            save()
        }
    }
}
