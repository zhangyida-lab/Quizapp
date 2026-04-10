import Foundation
import SwiftData

// MARK: - JSON 编码辅助（文件内私有）

private func sdEncoder() -> JSONEncoder {
    let enc = JSONEncoder()
    enc.dateEncodingStrategy = .iso8601
    return enc
}

private func sdDecoder() -> JSONDecoder {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    return dec
}

// MARK: - 题库持久化实体

@Model
final class QuestionBankEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var version: String
    var bankDescription: String   // 避免与 Swift 保留字 description 冲突
    var isBuiltIn: Bool
    var isEnabled: Bool
    var createdAt: Date
    /// JSON 编码的 [Question]
    var questionsData: Data

    init(bank: QuestionBank) {
        self.id              = bank.id
        self.name            = bank.name
        self.version         = bank.version
        self.bankDescription = bank.description
        self.isBuiltIn       = bank.isBuiltIn
        self.isEnabled       = bank.isEnabled
        self.createdAt       = bank.createdAt
        self.questionsData   = (try? sdEncoder().encode(bank.questions)) ?? Data()
    }

    func toStruct() -> QuestionBank {
        let qs = (try? sdDecoder().decode([Question].self, from: questionsData)) ?? []
        return QuestionBank(
            id: id, name: name, version: version, description: bankDescription,
            questions: qs, isBuiltIn: isBuiltIn, isEnabled: isEnabled, createdAt: createdAt
        )
    }

    func syncFrom(_ bank: QuestionBank) {
        name             = bank.name
        version          = bank.version
        bankDescription  = bank.description
        isBuiltIn        = bank.isBuiltIn
        isEnabled        = bank.isEnabled
        questionsData    = (try? sdEncoder().encode(bank.questions)) ?? Data()
    }
}

// MARK: - 错题记录持久化实体

@Model
final class WrongRecordEntity {
    @Attribute(.unique) var id: UUID
    var questionId: UUID
    var wrongCount: Int
    var correctStreak: Int
    var firstWrongDate: Date
    var lastAttemptDate: Date
    var nextReviewDate: Date
    var easeFactor: Double
    var intervalDays: Int
    var isMastered: Bool

    init(record: WrongRecord) {
        self.id              = record.id
        self.questionId      = record.questionId
        self.wrongCount      = record.wrongCount
        self.correctStreak   = record.correctStreak
        self.firstWrongDate  = record.firstWrongDate
        self.lastAttemptDate = record.lastAttemptDate
        self.nextReviewDate  = record.nextReviewDate
        self.easeFactor      = record.easeFactor
        self.intervalDays    = record.intervalDays
        self.isMastered      = record.isMastered
    }

    func toStruct() -> WrongRecord {
        var r              = WrongRecord(questionId: questionId)
        r.id               = id
        r.wrongCount       = wrongCount
        r.correctStreak    = correctStreak
        r.firstWrongDate   = firstWrongDate
        r.lastAttemptDate  = lastAttemptDate
        r.nextReviewDate   = nextReviewDate
        r.easeFactor       = easeFactor
        r.intervalDays     = intervalDays
        r.isMastered       = isMastered
        return r
    }

    func syncFrom(_ record: WrongRecord) {
        wrongCount       = record.wrongCount
        correctStreak    = record.correctStreak
        firstWrongDate   = record.firstWrongDate
        lastAttemptDate  = record.lastAttemptDate
        nextReviewDate   = record.nextReviewDate
        easeFactor       = record.easeFactor
        intervalDays     = record.intervalDays
        isMastered       = record.isMastered
    }
}

// MARK: - 试卷持久化实体

@Model
final class ExamPaperEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    /// JSON 编码的 ExamConfig
    var configData: Data
    /// JSON 编码的 [Question]（题目快照）
    var questionsData: Data
    /// JSON 编码的 [Int]（各题分值）
    var scoresData: Data
    /// JSON 编码的 [ExamAttempt]
    var attemptsData: Data

    init(paper: ExamPaper) {
        let enc           = sdEncoder()
        self.id           = paper.id
        self.title        = paper.title
        self.createdAt    = paper.createdAt
        self.configData   = (try? enc.encode(paper.config))          ?? Data()
        self.questionsData = (try? enc.encode(paper.questions))      ?? Data()
        self.scoresData   = (try? enc.encode(paper.questionScores))  ?? Data()
        self.attemptsData = (try? enc.encode(paper.attempts))        ?? Data()
    }

    func toStruct() -> ExamPaper? {
        let dec = sdDecoder()
        guard let config    = try? dec.decode(ExamConfig.self,  from: configData),
              let questions = try? dec.decode([Question].self,  from: questionsData),
              let scores    = try? dec.decode([Int].self,       from: scoresData)
        else { return nil }
        let attempts  = (try? dec.decode([ExamAttempt].self, from: attemptsData)) ?? []
        var paper     = ExamPaper(title: title, config: config,
                                  questions: questions, questionScores: scores)
        paper.id      = id
        paper.createdAt = createdAt
        paper.attempts  = attempts
        return paper
    }

    func syncFrom(_ paper: ExamPaper) {
        title          = paper.title
        let enc        = sdEncoder()
        configData     = (try? enc.encode(paper.config))         ?? Data()
        questionsData  = (try? enc.encode(paper.questions))      ?? Data()
        scoresData     = (try? enc.encode(paper.questionScores)) ?? Data()
        attemptsData   = (try? enc.encode(paper.attempts))       ?? Data()
    }
}

// MARK: - 应用设置持久化实体（单例）

@Model
final class AppSettingsEntity {
    /// JSON 编码的 [String]（隐藏分类名）
    var hiddenCatsData: Data
    /// JSON 编码的 [Question]（每日推荐缓存）
    var dailyQuestionsData: Data?
    var lastDailyDate: Date?

    init() {
        self.hiddenCatsData     = Data()
        self.dailyQuestionsData = nil
        self.lastDailyDate      = nil
    }
}
