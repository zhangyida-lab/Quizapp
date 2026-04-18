import Foundation

// MARK: - FSRS-4.5 间隔重复算法引擎
// 参考：https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
// 使用预训练默认权重，无需用户调参即可获得良好效果。

enum FSRSEngine {

    // FSRS-4.5 默认权重 w[0]...w[16]，基于真实闪卡数据训练
    private static let w: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722,
        7.2102, 0.5316, 1.0651, 0.0589,
        1.5330, 0.1544, 1.0071, 1.9395,
        0.1100, 0.2900, 2.2700, 0.0000,
        2.9898
    ]

    // MARK: - 首次学习初始化

    /// 初始记忆稳定性（天）
    /// - correct = true  → Good (rating=3)：约 3.1 天
    /// - correct = false → Again (rating=1)：约 0.4 天
    static func initialStability(correct: Bool) -> Double {
        correct ? w[2] : w[0]
    }

    /// 初始难度（1~10）
    static func initialDifficulty(correct: Bool) -> Double {
        let r = correct ? 3.0 : 1.0
        return clamp(w[4] - exp(w[5] * (r - 1)) + 1, lo: 1, hi: 10)
    }

    // MARK: - 核心公式

    /// 可提取性（记忆概率）R(t, S)
    /// - elapsed: 距上次复习的天数
    /// - stability: 当前记忆稳定性（天）
    static func retrievability(elapsed: Double, stability: Double) -> Double {
        // 避免 elapsed≈0 时 R≈1，导致首次当天复习时稳定性异常
        let t = max(0.001, elapsed)
        return pow(1.0 + t / (9.0 * stability), -1.0)
    }

    /// 根据目标记忆保留率，计算下次复习应间隔的天数
    /// 推导：targetRetention = (1 + t / (9S))^{-1}  →  t = 9S * (1/R - 1)
    static func nextInterval(stability: Double, targetRetention: Double) -> Int {
        let days = 9.0 * stability * (1.0 / targetRetention - 1.0)
        return max(1, Int(days.rounded()))
    }

    // MARK: - 稳定性更新

    /// 答对后的新稳定性（记忆巩固）
    static func nextStabilityRecall(d: Double, s: Double, r: Double) -> Double {
        let gain = exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1)
        return max(0.1, s * gain + 1)
    }

    /// 答错后的新稳定性（遗忘后重学）
    static func nextStabilityForget(d: Double, s: Double, r: Double) -> Double {
        let sf = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14])
        return max(0.1, sf)
    }

    // MARK: - 难度更新

    /// 更新难度：答对不变（或小幅向均值回归）；答错升高
    static func nextDifficulty(d: Double, correct: Bool) -> Double {
        let rating = correct ? 3.0 : 1.0
        let delta  = -w[6] * (rating - 3.0)                      // 答错+2w[6], 答对=0
        let d0_4   = clamp(w[4] - exp(w[5] * 3) + 1, lo: 1, hi: 10)  // D₀(Easy) 均值回归基准
        let d1     = d + delta
        let d2     = w[7] * d0_4 + (1 - w[7]) * d1              // 均值回归，防止难度漂移
        return clamp(d2, lo: 1, hi: 10)
    }

    // MARK: - 内部工具

    private static func clamp(_ v: Double, lo: Double, hi: Double) -> Double {
        min(hi, max(lo, v))
    }
}
