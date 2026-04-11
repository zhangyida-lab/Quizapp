import Foundation

// MARK: - App Groups 共享 UserDefaults
// 定义在此处，供主 App 和所有 Extension 共用
extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.com.acspace.Lexora") ?? .standard
}

// MARK: - 轻量级共享数据访问层
// 供 Siri App Intent / Widget Extension 使用
// 不依赖 SwiftUI / ObservableObject，可在 Extension 中安全调用

enum VocabSharedHelper {

    // MARK: 快速添加生词
    /// 返回 true = 添加成功，false = 单词已存在
    @discardableResult
    static func quickAdd(word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        var books = loadBooks()
        let lower = trimmed.lowercased()

        // 已存在则不重复添加
        let exists = books.flatMap { $0.words }.contains { $0.word.lowercased() == lower }
        if exists { return false }

        let newWord = Word(
            word: trimmed,
            phonetic: "",
            partOfSpeech: "n.",
            definitions: [Word.Definition(meaning: "（待补充释义）", exampleEn: nil, exampleZh: nil)],
            source: .manual
        )

        // 找「我的生词本」，没有则创建
        if let idx = books.firstIndex(where: { $0.name == "我的生词本" && !$0.isBuiltIn }) {
            books[idx].words.append(newWord)
        } else {
            var myBook = WordBook(
                name: "我的生词本",
                level: "自定义",
                description: "通过 Siri / Widget 快速添加的生词"
            )
            myBook.words.append(newWord)
            books.append(myBook)
        }

        saveBooks(books)
        return true
    }

    // MARK: 读取统计信息（供 Widget 展示）
    static func stats() -> VocabStats {
        let records = loadRecords()
        // 优先使用主 App 缓存的总词数（包含内置词库）
        // 内置词库单词不存入 UserDefaults，由主 App 在 save() 时写入缓存 key
        let cachedTotal = UserDefaults.shared.integer(forKey: "vocab_total_count_v1")
        let total: Int
        if cachedTotal > 0 {
            total = cachedTotal
        } else {
            // 降级：仅统计用户词库（首次启动前 Widget 可能读到 0）
            let books = loadBooks()
            total = books.filter { $0.isEnabled }.flatMap { $0.words }.count
        }
        let due      = records.filter { $0.isDue }.count
        let mastered = records.filter { $0.isMastered }.count
        return VocabStats(totalWords: total, dueCount: due, masteredCount: mastered)
    }

    // MARK: 读取今日单词（供 Widget 展示）
    static func todayWords(limit: Int = 5) -> [Word] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = UserDefaults.shared.data(forKey: "vocab_daily_v1"),
              let words = try? decoder.decode([Word].self, from: data) else {
            return []
        }
        return Array(words.prefix(limit))
    }

    // MARK: 私有：读写词库
    private static func loadBooks() -> [WordBook] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = UserDefaults.shared.data(forKey: "vocab_books_v1"),
              let books = try? decoder.decode([WordBook].self, from: data) else {
            return []
        }
        return books
    }

    private static func saveBooks(_ books: [WordBook]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(books) {
            UserDefaults.shared.set(data, forKey: "vocab_books_v1")
        }
    }

    private static func loadRecords() -> [WordRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = UserDefaults.shared.data(forKey: "vocab_records_v1"),
              let records = try? decoder.decode([WordRecord].self, from: data) else {
            return []
        }
        return records
    }
}

// MARK: - Widget 统计数据
struct VocabStats {
    let totalWords: Int
    let dueCount: Int
    let masteredCount: Int
}
