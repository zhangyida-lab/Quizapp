import Foundation

// MARK: - 内置词库目录
// JSON 文件放在 WordBooks/ 文件夹，打包进 App Bundle
// 单词不存入 UserDefaults，只在用户启用后从 Bundle 懒加载到内存

enum BuiltInWordBooks {

    struct Meta {
        let id: UUID
        let fileName: String   // Bundle 内 JSON 文件名（不含扩展名）
        let name: String
        let level: String
        let description: String
        let wordCount: Int     // 用于在未启用时展示单词数量
    }

    static let catalog: [Meta] = [
        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000001")!,
             fileName: "MiddleSchool",
             name: "初中英语", level: "初中",
             description: "初中英语核心词汇", wordCount: 3223),

        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000002")!,
             fileName: "HighSchool",
             name: "高中英语", level: "高中",
             description: "高中英语核心词汇", wordCount: 6008),

        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000003")!,
             fileName: "CET-4",
             name: "CET-4 精选版", level: "CET-4",
             description: "四级高频核心词精选", wordCount: 50),

        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000004")!,
             fileName: "CET4-Full",
             name: "CET-4 完整版", level: "CET-4",
             description: "大学英语四级完整词汇", wordCount: 7508),

        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000005")!,
             fileName: "CET-6",
             name: "CET-6 精选版", level: "CET-6",
             description: "六级高频核心词精选", wordCount: 50),

        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000006")!,
             fileName: "CET6-Full",
             name: "CET-6 完整版", level: "CET-6",
             description: "大学英语六级完整词汇", wordCount: 5651),

        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000007")!,
             fileName: "Postgraduate",
             name: "考研英语", level: "考研",
             description: "考研英语核心词汇", wordCount: 9602),

        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000008")!,
             fileName: "TOEFL",
             name: "托福词汇", level: "TOEFL",
             description: "托福核心词汇", wordCount: 13477),

        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000009")!,
             fileName: "SAT",
             name: "SAT 词汇", level: "SAT",
             description: "SAT 核心词汇", wordCount: 8887),

        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000010")!,
             fileName: "BusinessEnglish",
             name: "商务英语", level: "商务",
             description: "职场商务英语常用词", wordCount: 45),

        Meta(id: UUID(uuidString: "12000000-0000-0000-0000-000000000011")!,
             fileName: "SoftwareEngineer",
             name: "软件工程英语", level: "技术",
             description: "软件工程师常用英语词汇", wordCount: 45),
    ]

    // MARK: 判断是否是内置词库 ID
    static let catalogIds: Set<UUID> = Set(catalog.map { $0.id })

    static func isBuiltIn(_ id: UUID) -> Bool {
        catalogIds.contains(id)
    }

    // MARK: 从 Bundle 加载单词（同步，在后台线程调用）
    static func loadWords(for meta: Meta) -> [Word] {
        guard let url = Bundle.main.url(forResource: meta.fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode(WordBookImport.self, from: data) else { return [] }
        return imported.toWordBook().words
    }
}
