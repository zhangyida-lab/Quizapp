import Foundation

// MARK: - 单词模型
struct Word: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var word: String              // 英文单词
    var phonetic: String          // 音标 "/ˈæpəl/"
    var partOfSpeech: String      // 词性 "n." "v." "adj."
    var definitions: [Definition]
    var tags: [String]
    var difficulty: Int           // 1-5
    var source: Source
    var createdAt: Date

    struct Definition: Codable, Equatable, Hashable {
        var meaning: String       // 中文释义
        var exampleEn: String?    // 英文例句
        var exampleZh: String?    // 例句中文翻译
    }

    enum Source: String, Codable {
        case builtIn  = "builtIn"
        case imported = "imported"
        case manual   = "manual"
    }

    /// 首条释义（用于选项、列表展示）
    var primaryMeaning: String { definitions.first?.meaning ?? "" }

    init(
        id: UUID = UUID(),
        word: String,
        phonetic: String = "",
        partOfSpeech: String = "n.",
        definitions: [Definition],
        tags: [String] = [],
        difficulty: Int = 3,
        source: Source = .builtIn,
        createdAt: Date = Date()
    ) {
        self.id = id; self.word = word; self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech; self.definitions = definitions
        self.tags = tags; self.difficulty = difficulty
        self.source = source; self.createdAt = createdAt
    }
}

// MARK: - 词库
struct WordBook: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var level: String             // "CET-4" "CET-6" "IELTS" "自定义"
    var bookDescription: String
    var words: [Word]
    var isBuiltIn: Bool
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        level: String = "自定义",
        description: String = "",
        words: [Word] = [],
        isBuiltIn: Bool = false,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id; self.name = name; self.level = level
        self.bookDescription = description; self.words = words
        self.isBuiltIn = isBuiltIn; self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var totalCount: Int { words.count }
}

// MARK: - 单词记忆记录（SM-2 间隔重复算法）
struct WordRecord: Identifiable, Codable {
    var id: UUID
    var wordId: UUID

    var studyCount: Int           // 总学习次数
    var correctStreak: Int        // 连续答对次数

    var firstStudyDate: Date
    var lastStudyDate: Date
    var nextReviewDate: Date      // 下次复习时间

    var easeFactor: Double        // SM-2 难度系数，初始 2.5，最低 1.3
    var intervalDays: Int         // 当前间隔（天）
    var isMastered: Bool

    init(wordId: UUID, date: Date = Date()) {
        self.id = UUID(); self.wordId = wordId
        self.studyCount = 0; self.correctStreak = 0
        self.firstStudyDate = date; self.lastStudyDate = date
        self.nextReviewDate = date
        self.easeFactor = 2.5; self.intervalDays = 1; self.isMastered = false
    }

    // MARK: SM-2 更新
    mutating func update(isCorrect: Bool) {
        lastStudyDate = Date()
        studyCount += 1
        let quality = isCorrect ? 4 : 1
        if isCorrect {
            correctStreak += 1
            switch correctStreak {
            case 1:  intervalDays = 1
            case 2:  intervalDays = 3
            default: intervalDays = max(1, Int((Double(intervalDays) * easeFactor).rounded()))
            }
            easeFactor = max(1.3, easeFactor + 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02))
        } else {
            correctStreak = 0; intervalDays = 1
            easeFactor = max(1.3, easeFactor - 0.2)
        }
        nextReviewDate = Calendar.current.date(byAdding: .day, value: intervalDays, to: Date()) ?? Date()
    }

    var isDue: Bool { !isMastered && Date() >= nextReviewDate }

    var masteryLevel: String {
        if isMastered      { return "已掌握" }
        if correctStreak >= 3 { return "较熟练" }
        if correctStreak >= 1 { return "进步中" }
        return "待巩固"
    }

    var masteryColorName: String {
        if isMastered      { return "green" }
        if correctStreak >= 3 { return "blue" }
        if correctStreak >= 1 { return "yellow" }
        return "red"
    }
}
