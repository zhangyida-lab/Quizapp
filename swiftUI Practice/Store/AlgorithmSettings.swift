import Foundation
import SwiftUI

// MARK: - 算法配置（所有可调参数）

struct AlgorithmConfig: Codable {

    // MARK: 每日题目推荐
    var dailyQuestionCount: Int = 20          // 每日推荐题数（10-40）
    var dueQuestionMaxRatio: Double = 0.75    // 错题占比上限（0-1）
    var useWeightedFill: Bool = true          // 补充题是否按薄弱点加权（false=纯随机）

    // MARK: 单词学习
    var dailyWordCount: Int = 20              // 每日单词数（10-50）
    var newWordRatio: Double = 0.30           // 新词占比（0-1），其余为复习词

    // MARK: SM-2 间隔参数（题目 & 单词共用）
    var sm2WrongResetDays: Int = 1            // 答错后复习间隔重置（1-3天）
    var sm2MinEaseFactor: Double = 1.3        // 最低难度系数（1.3-2.0）
    var sm2EasePenalty: Double = 0.2          // 答错后难度系数降幅（0.1-0.4）

    // MARK: 试卷生成
    var examDefaultCount: Int = 20            // 默认出题数（5-50）
    var examDifficulty: ExamDifficultyPreset = .balanced

    // MARK: 试卷难度预设
    enum ExamDifficultyPreset: String, Codable, CaseIterable, Identifiable {
        case easy     = "偏易"
        case balanced = "均衡"
        case hard     = "偏难"

        var id: String { rawValue }

        /// 难度 1-2 / 3 / 4-5 各占比例
        var distribution: (easy: Double, medium: Double, hard: Double) {
            switch self {
            case .easy:     return (0.50, 0.35, 0.15)
            case .balanced: return (0.30, 0.50, 0.20)
            case .hard:     return (0.15, 0.35, 0.50)
            }
        }

        var description: String {
            switch self {
            case .easy:     return "易 50% · 中 35% · 难 15%"
            case .balanced: return "易 30% · 中 50% · 难 20%"
            case .hard:     return "易 15% · 中 35% · 难 50%"
            }
        }
    }
}

// MARK: - 算法设置仓库

class AlgorithmSettingsStore: ObservableObject {
    @Published var config: AlgorithmConfig {
        didSet { save() }
    }

    private static let key = "algorithm_settings_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(AlgorithmConfig.self, from: data) {
            config = saved
        } else {
            config = AlgorithmConfig()
        }
    }

    /// 供 QuizStore / VocabularyStore 在无法访问 environment 时读取当前配置
    static func loadConfig() -> AlgorithmConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(AlgorithmConfig.self, from: data)
        else { return AlgorithmConfig() }
        return saved
    }

    func resetToDefaults() {
        config = AlgorithmConfig()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
