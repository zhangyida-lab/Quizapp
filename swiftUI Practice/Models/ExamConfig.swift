import Foundation

// MARK: - 试卷配置
struct ExamConfig: Equatable, Codable {
    var subjects: Set<String>
    var difficulties: Set<Int>
    var totalCount: Int
    var totalScore: Int
    var scoreMode: ScoreMode
    var examMode: ExamMode        // 新增：考试/练习模式

    enum ScoreMode: String, Codable, CaseIterable, Identifiable {
        case uniform      = "统一分值"
        case byDifficulty = "按难度分层"
        var id: String { rawValue }
    }

    enum ExamMode: String, Codable, CaseIterable, Identifiable {
        case practice = "练习模式"   // 即时反馈
        case exam     = "考试模式"   // 交卷后才显示对错
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .practice: return "bolt.fill"
            case .exam:     return "lock.fill"
            }
        }
        var description: String {
            switch self {
            case .practice: return "每题作答后立即显示对错"
            case .exam:     return "所有题作答完毕交卷后才显示结果"
            }
        }
    }

    // MARK: 从题库中筛选并随机抽题
    func selectQuestions(from all: [Question]) -> [Question] {
        let filtered = all.filter {
            subjects.contains($0.category) && difficulties.contains($0.difficulty)
        }
        return Array(filtered.shuffled().prefix(totalCount))
    }

    // MARK: 计算每题分值，确保总和 == totalScore
    func scores(for questions: [Question]) -> [Int] {
        guard !questions.isEmpty else { return [] }
        switch scoreMode {
        case .uniform:
            let base = totalScore / questions.count
            let rem  = totalScore - base * questions.count
            return questions.indices.map { i in
                i == questions.count - 1 ? base + rem : base
            }
        case .byDifficulty:
            let weights: [Double] = questions.map { q in
                switch q.difficulty {
                case 1, 2: return 1.0
                case 3:    return 2.0
                default:   return 3.0
                }
            }
            let totalW = weights.reduce(0, +)
            var result = weights.map { w in
                max(1, Int((w / totalW * Double(totalScore)).rounded()))
            }
            let diff = totalScore - result.reduce(0, +)
            result[result.count - 1] = max(1, result[result.count - 1] + diff)
            return result
        }
    }

    // MARK: 当前配置可用题目数
    func availableCount(from all: [Question]) -> Int {
        all.filter {
            subjects.contains($0.category) && difficulties.contains($0.difficulty)
        }.count
    }

    // MARK: 自动生成试卷标题
    func autoTitle(actualCount: Int) -> String {
        let subStr = subjects.sorted().joined(separator: "·")
        return "\(subStr) · \(actualCount)题 · \(totalScore)分"
    }
}
