import Foundation

// MARK: - 图片数据（Codable）
struct QuestionImageData: Codable, Equatable, Hashable {
    enum ImageType: String, Codable {
        case asset   // Assets.xcassets 中的图片名称
        case url     // 远程 URL
        case file    // 本地文件路径（拍照收集）
    }
    let type: ImageType
    let value: String
}

// MARK: - 题目模型
struct Question: Identifiable, Codable, Equatable {
    var id: UUID
    var category: String
    var text: String
    var image: QuestionImageData?
    var options: [String]
    var correctIndex: Int
    var difficulty: Int          // 1-5，默认 3
    var explanation: String?     // AI 解析预留字段
    var tags: [String]
    var source: Source
    var createdAt: Date

    enum Source: String, Codable {
        case builtIn   = "builtIn"
        case imported  = "imported"
        case photo     = "photo"
        case manual    = "manual"
    }

    init(
        id: UUID = UUID(),
        category: String,
        text: String,
        image: QuestionImageData? = nil,
        options: [String],
        correctIndex: Int,
        difficulty: Int = 3,
        explanation: String? = nil,
        tags: [String] = [],
        source: Source = .builtIn,
        createdAt: Date = Date()
    ) {
        self.id = id; self.category = category; self.text = text
        self.image = image; self.options = options; self.correctIndex = correctIndex
        self.difficulty = difficulty; self.explanation = explanation
        self.tags = tags; self.source = source; self.createdAt = createdAt
    }
}

// MARK: - 题库
struct QuestionBank: Identifiable, Codable {
    var id: UUID
    var name: String
    var version: String
    var description: String
    var questions: [Question]
    var isBuiltIn: Bool
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        version: String = "1.0",
        description: String = "",
        questions: [Question] = [],
        isBuiltIn: Bool = false,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id; self.name = name; self.version = version
        self.description = description; self.questions = questions
        self.isBuiltIn = isBuiltIn; self.isEnabled = isEnabled; self.createdAt = createdAt
    }

    var totalCount: Int { questions.count }
}

// MARK: - JSON 导入格式（宽松解析）
struct QuestionBankImport: Codable {
    let version: String
    let name: String
    let description: String?
    let questions: [QuestionImport]

    struct QuestionImport: Codable {
        let id: String?
        let category: String
        let text: String
        let image: ImageImport?
        let options: [String]
        let correctIndex: Int
        let difficulty: Int?
        let explanation: String?
        let tags: [String]?

        struct ImageImport: Codable {
            let type: String  // "url" | "asset"
            let value: String
        }
    }

    func toQuestionBank() -> QuestionBank {
        let qs = questions.map { q -> Question in
            let imgData: QuestionImageData? = q.image.map { img in
                let t: QuestionImageData.ImageType = img.type == "asset" ? .asset : .url
                return QuestionImageData(type: t, value: img.value)
            }
            return Question(
                id: q.id.flatMap { UUID(uuidString: $0) } ?? UUID(),
                category: q.category,
                text: q.text,
                image: imgData,
                options: q.options,
                correctIndex: q.correctIndex,
                difficulty: q.difficulty ?? 3,
                explanation: q.explanation,
                tags: q.tags ?? [],
                source: .imported
            )
        }
        return QuestionBank(
            name: name,
            version: version,
            description: description ?? "",
            questions: qs,
            isBuiltIn: false,
            isEnabled: true
        )
    }
}
