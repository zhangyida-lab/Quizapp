import Foundation

// MARK: - FSRS 4 级评分
enum FSRSRating: Int, Codable, CaseIterable {
    case again = 1  // 完全忘记，需重来
    case hard  = 2  // 很困难，勉强记住
    case good  = 3  // 正常回忆
    case easy  = 4  // 轻松记住

    var isCorrect: Bool { self != .again }

    var label: String {
        switch self {
        case .again: return "重来"
        case .hard:  return "困难"
        case .good:  return "良好"
        case .easy:  return "简单"
        }
    }
}

// MARK: - FSRS-4.5 间隔重复算法引擎
// 参考：https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
enum FSRSEngine {
    // FSRS-4.5 默认权重 w[0]...w[16]，基于真实闪卡数据训练
    private static let w: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722,
        7.2102, 0.5316, 1.0651, 0.0589,
        1.5330, 0.1544, 1.0071, 1.9395,
        0.1100, 0.2900, 2.2700, 0.0000,
        2.9898
    ]

    // w[0]=Again, w[1]=Hard, w[2]=Good, w[3]=Easy
    static func initialStability(rating: FSRSRating) -> Double { w[rating.rawValue - 1] }

    static func initialDifficulty(rating: FSRSRating) -> Double {
        let r = Double(rating.rawValue)
        return clamp(w[4] - exp(w[5] * (r - 1)) + 1, lo: 1, hi: 10)
    }

    static func retrievability(elapsed: Double, stability: Double) -> Double {
        let t = max(0.001, elapsed)
        return pow(1.0 + t / (9.0 * stability), -1.0)
    }

    static func nextInterval(stability: Double, targetRetention: Double) -> Int {
        let days = 9.0 * stability * (1.0 / targetRetention - 1.0)
        return max(1, Int(days.rounded()))
    }

    // Hard 评级时稳定性不增长（w[15]=0）；Easy 有额外加成（w[16]≈3）
    static func nextStabilityRecall(d: Double, s: Double, r: Double, rating: FSRSRating) -> Double {
        let hardPenalty = rating == .hard ? w[15] : 1.0
        let easyBonus   = rating == .easy ? w[16] : 1.0
        let gain = exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1)
                   * hardPenalty * easyBonus
        return max(0.1, s * gain + 1)
    }

    static func nextStabilityForget(d: Double, s: Double, r: Double) -> Double {
        let sf = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14])
        return max(0.1, sf)
    }

    static func nextDifficulty(d: Double, rating: FSRSRating) -> Double {
        let rVal  = Double(rating.rawValue)
        let delta = -w[6] * (rVal - 3.0)       // Again→+2w[6], Hard→+w[6], Good→0, Easy→-w[6]
        let d0_4  = clamp(w[4] - exp(w[5] * 3) + 1, lo: 1, hi: 10)
        let d2    = w[7] * d0_4 + (1 - w[7]) * (d + delta)
        return clamp(d2, lo: 1, hi: 10)
    }

    private static func clamp(_ v: Double, lo: Double, hi: Double) -> Double {
        min(hi, max(lo, v))
    }
}

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

    // MARK: - FSRS 算法更新（4 级评分）
    mutating func updateFSRS(rating: FSRSRating, targetRetention: Double) {
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(lastAttemptDate) / 86400)

        if rating.isCorrect { correctStreak += 1 } else { wrongCount += 1; correctStreak = 0 }

        if fsrsStability == nil || fstrsDifficulty == nil {
            fsrsStability   = FSRSEngine.initialStability(rating: rating)
            fstrsDifficulty = FSRSEngine.initialDifficulty(rating: rating)
        } else {
            let s = fsrsStability!, d = fstrsDifficulty!
            let r = FSRSEngine.retrievability(elapsed: elapsed, stability: s)
            fsrsStability   = rating.isCorrect
                ? FSRSEngine.nextStabilityRecall(d: d, s: s, r: r, rating: rating)
                : FSRSEngine.nextStabilityForget(d: d, s: s, r: r)
            fstrsDifficulty = FSRSEngine.nextDifficulty(d: d, rating: rating)
        }

        lastAttemptDate = now
        let days = FSRSEngine.nextInterval(stability: fsrsStability!, targetRetention: targetRetention)
        intervalDays   = days
        nextReviewDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
    }

    /// 便捷包装：二元答对/答错 → 映射为 Good / Again
    mutating func updateFSRS(isCorrect: Bool, targetRetention: Double) {
        updateFSRS(rating: isCorrect ? .good : .again, targetRetention: targetRetention)
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
