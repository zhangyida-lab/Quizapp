import Foundation

// MARK: - 备份数据结构

struct LexoraBackup: Codable {
    var version: String = "1.0"
    var exportDate: Date = Date()
    // 答题模块
    var questionBanks: [QuestionBank]
    var wrongRecords: [WrongRecord]
    var examPapers: [ExamPaper]
    var hiddenCategories: [String]
    // 词汇模块
    var wordBooks: [WordBook]
    var wordRecords: [WordRecord]
    var builtInEnabledIds: [String]
    // 算法设置
    var algorithmConfig: AlgorithmConfig
}

// MARK: - 备份错误

enum BackupError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:  return "数据编码失败，请重试"
        case .decodingFailed:  return "备份文件格式无效，无法读取"
        case .fileWriteFailed: return "临时文件写入失败，请重试"
        }
    }
}

// MARK: - 备份管理器

struct BackupManager {

    // MARK: 导出

    static func export(
        quizStore: QuizStore,
        vocabStore: VocabularyStore,
        algoStore: AlgorithmSettingsStore
    ) throws -> URL {
        let enabledIds = (UserDefaults.shared.array(forKey: VocabularyStore.Keys.builtInEnabled) as? [String]) ?? []

        let backup = LexoraBackup(
            exportDate: Date(),
            questionBanks: quizStore.questionBanks.filter { !$0.isBuiltIn },
            wrongRecords: quizStore.wrongRecords,
            examPapers: quizStore.examPapers,
            hiddenCategories: Array(quizStore.hiddenCategories),
            wordBooks: vocabStore.wordBooks.filter { !$0.isBuiltIn },
            wordRecords: vocabStore.wordRecords,
            builtInEnabledIds: enabledIds,
            algorithmConfig: algoStore.config
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(backup) else { throw BackupError.encodingFailed }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let fileName = "Lexora-backup-\(fmt.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard (try? data.write(to: url)) != nil else { throw BackupError.fileWriteFailed }
        return url
    }

    // MARK: 导入恢复

    static func restore(
        from url: URL,
        into quizStore: QuizStore,
        vocabStore: VocabularyStore,
        algoStore: AlgorithmSettingsStore
    ) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw BackupError.decodingFailed }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(LexoraBackup.self, from: data) else {
            throw BackupError.decodingFailed
        }

        quizStore.restoreFromBackup(backup)
        vocabStore.restoreFromBackup(backup)
        algoStore.config = backup.algorithmConfig
    }
}
