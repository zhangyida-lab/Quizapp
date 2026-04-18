import Foundation

// MARK: - 错题记录（SM-2 间隔重复算法）
struct WrongRecord: Identifiable, Codable {
    var id: UUID
    var questionId: UUID

    var wrongCount: Int       // 累计答错次数
    var correctStreak: Int    // 当前连续答对次数

    var firstWrongDate: Date
    var lastAttemptDate: Date
    var nextReviewDate: Date  // 下次应复习时间（算法计算）

    // SM-2 参数
    var easeFactor: Double    // 难度系数，初始 2.5，最低 1.3
    var intervalDays: Int     // 当前复习间隔（天）

    // FSRS 参数（可选；nil = 尚未用 FSRS 复习过）
    var fsrsStability: Double?    // 记忆稳定性（天）
    var fstrsDifficulty: Double?  // FSRS 难度（1~10）

    var isMastered: Bool      // 用户标记已掌握

    // MARK: - 初始化
    init(questionId: UUID, date: Date = Date()) {
        self.id = UUID()
        self.questionId = questionId
        self.wrongCount = 0
        self.correctStreak = 0
        self.firstWrongDate = date
        self.lastAttemptDate = date
        self.nextReviewDate = date   // 立即复习
        self.easeFactor = 2.5
        self.intervalDays = 1
        self.isMastered = false
    }

    // MARK: - SM-2 算法更新
    mutating func update(isCorrect: Bool,
                         wrongResetDays: Int = 1,
                         minEaseFactor: Double = 1.3,
                         easePenalty: Double = 0.2) {
        let quality = isCorrect ? 4 : 1
        lastAttemptDate = Date()

        if isCorrect {
            correctStreak += 1
            switch correctStreak {
            case 1:  intervalDays = 1
            case 2:  intervalDays = 3
            default: intervalDays = max(1, Int((Double(intervalDays) * easeFactor).rounded()))
            }
            easeFactor = max(minEaseFactor, easeFactor + 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02))
        } else {
            wrongCount += 1
            correctStreak = 0
            intervalDays = wrongResetDays
            easeFactor = max(minEaseFactor, easeFactor - easePenalty)
        }

        nextReviewDate = Calendar.current.date(byAdding: .day, value: intervalDays, to: Date()) ?? Date()
    }

    // MARK: - FSRS 算法更新
    mutating func updateFSRS(isCorrect: Bool, targetRetention: Double) {
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(lastAttemptDate) / 86400)

        if isCorrect {
            correctStreak += 1
        } else {
            wrongCount += 1
            correctStreak = 0
        }

        if fsrsStability == nil || fstrsDifficulty == nil {
            // 首次 FSRS 复习：根据答题结果初始化稳定性和难度
            fsrsStability   = FSRSEngine.initialStability(correct: isCorrect)
            fstrsDifficulty = FSRSEngine.initialDifficulty(correct: isCorrect)
        } else {
            let s = fsrsStability!
            let d = fstrsDifficulty!
            let r = FSRSEngine.retrievability(elapsed: elapsed, stability: s)
            fsrsStability   = isCorrect
                ? FSRSEngine.nextStabilityRecall(d: d, s: s, r: r)
                : FSRSEngine.nextStabilityForget(d: d, s: s, r: r)
            fstrsDifficulty = FSRSEngine.nextDifficulty(d: d, correct: isCorrect)
        }

        lastAttemptDate = now
        let days = FSRSEngine.nextInterval(stability: fsrsStability!, targetRetention: targetRetention)
        intervalDays   = days
        nextReviewDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
    }

    // MARK: - 工具属性
    /// 是否到了复习时间
    var isDue: Bool {
        !isMastered && Date() >= nextReviewDate
    }

    /// 推荐优先级（越高越应该优先复习）
    var priorityScore: Double {
        guard !isMastered else { return -1 }
        let overdueDays = max(0.0, -nextReviewDate.timeIntervalSinceNow / 86400)
        let urgency: Double = correctStreak == 0 ? 3 : 0
        return Double(wrongCount) * 3 + overdueDays * 2 + urgency
    }

    /// 掌握程度描述
    var masteryLevel: String {
        if isMastered { return "已掌握" }
        if correctStreak >= 3 { return "较熟练" }
        if correctStreak >= 1 { return "进步中" }
        return "待巩固"
    }

    var masteryColor: String {
        if isMastered { return "green" }
        if correctStreak >= 3 { return "blue" }
        if correctStreak >= 1 { return "yellow" }
        return "red"
    }
}
