import Foundation

// MARK: - 试卷（含题目快照）
struct ExamPaper: Identifiable, Codable {
    var id: UUID
    var title: String
    var config: ExamConfig          // 组卷配置快照
    var questions: [Question]       // 题目快照（与题库解耦）
    var questionScores: [Int]       // 各题分值
    var createdAt: Date
    var attempts: [ExamAttempt]     // 历史作答记录

    init(title: String, config: ExamConfig,
         questions: [Question], questionScores: [Int]) {
        self.id            = UUID()
        self.title         = title
        self.config        = config
        self.questions     = questions
        self.questionScores = questionScores
        self.createdAt     = Date()
        self.attempts      = []
    }

    var totalScore: Int    { questionScores.reduce(0, +) }
    var totalCount: Int    { questions.count }
    var attemptCount: Int  { attempts.count }

    var bestAttempt: ExamAttempt? {
        attempts.max { $0.earnedScore < $1.earnedScore }
    }
    var lastAttempt: ExamAttempt? {
        attempts.max { $0.finishedAt < $1.finishedAt }
    }
    var bestScore: Int { bestAttempt?.earnedScore ?? 0 }
}

// MARK: - 单次作答记录
struct ExamAttempt: Identifiable, Codable {
    var id: UUID
    var startedAt: Date
    var finishedAt: Date
    var answers: [Int: Int]    // 题目索引 → 所选选项索引
    var earnedScore: Int
    var totalScore: Int
    var correctCount: Int
    var totalCount: Int

    init(startedAt: Date, finishedAt: Date = Date(),
         answers: [Int: Int], earnedScore: Int,
         totalScore: Int, correctCount: Int, totalCount: Int) {
        self.id           = UUID()
        self.startedAt    = startedAt
        self.finishedAt   = finishedAt
        self.answers      = answers
        self.earnedScore  = earnedScore
        self.totalScore   = totalScore
        self.correctCount = correctCount
        self.totalCount   = totalCount
    }

    var percentage: Int {
        guard totalScore > 0 else { return 0 }
        return Int(Double(earnedScore) / Double(totalScore) * 100)
    }
    var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }
    var durationText: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return m > 0 ? "\(m)分\(s)秒" : "\(s)秒"
    }
}
