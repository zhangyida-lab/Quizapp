import Foundation
import SwiftUI

// MARK: - 分类展示信息
struct CategoryInfo: Identifiable, Equatable {
    let id: String          // 分类名称即 id
    var name: String
    var questionCount: Int

    var icon: String {
        switch name {
        case "地理": return "globe.asia.australia.fill"
        case "科学": return "atom"
        case "历史": return "scroll.fill"
        case "数学": return "function"
        case "艺术": return "paintpalette.fill"
        case "体育": return "figure.run"
        default:    return "folder.fill"
        }
    }

    var color: Color {
        switch name {
        case "地理": return Color(red: 0.20, green: 0.60, blue: 0.86)
        case "科学": return Color(red: 0.33, green: 0.78, blue: 0.62)
        case "历史": return Color(red: 0.86, green: 0.55, blue: 0.25)
        case "数学": return Color(red: 0.53, green: 0.40, blue: 0.88)
        case "艺术": return Color(red: 0.88, green: 0.35, blue: 0.55)
        case "体育": return Color(red: 0.25, green: 0.72, blue: 0.45)
        default:
            // 为未知分类生成稳定颜色
            let h = Double(abs(name.hashValue) % 360) / 360.0
            return Color(hue: h, saturation: 0.6, brightness: 0.75)
        }
    }

    var description: String {
        switch name {
        case "地理": return "探索世界地理知识"
        case "科学": return "挑战自然科学题目"
        case "历史": return "回顾历史长河"
        case "数学": return "数字与逻辑的世界"
        case "艺术": return "感受艺术之美"
        case "体育": return "体育竞技大考验"
        default:    return "挑战此分类题目"
        }
    }
}

// MARK: - 中央数据仓库
class QuizStore: ObservableObject {
    @Published var questionBanks: [QuestionBank] = []
    @Published var wrongRecords:  [WrongRecord]  = []
    @Published var dailyQuestions: [Question]    = []
    @Published var examPapers:    [ExamPaper]    = []
    @Published var hiddenCategories: Set<String> = []

    private var lastDailyDate: Date?

    // MARK: 计算属性
    var allQuestions: [Question] {
        questionBanks.filter { $0.isEnabled }.flatMap { $0.questions }
    }

    /// 所有分类（含隐藏），用于管理界面
    var allCategories: [CategoryInfo] {
        let grouped = Dictionary(grouping: allQuestions, by: { $0.category })
        return grouped
            .map { CategoryInfo(id: $0.key, name: $0.key, questionCount: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    /// 可见分类（已过滤隐藏），用于首页展示
    var categories: [CategoryInfo] {
        allCategories.filter { !hiddenCategories.contains($0.name) }
    }

    func isCategoryHidden(_ name: String) -> Bool {
        hiddenCategories.contains(name)
    }

    func toggleCategoryHidden(_ name: String) {
        if hiddenCategories.contains(name) {
            hiddenCategories.remove(name)
        } else {
            hiddenCategories.insert(name)
        }
        generateDailyRecommendations()
        save()
    }

    func questions(for categoryName: String) -> [Question] {
        allQuestions.filter { $0.category == categoryName }.shuffled()
    }

    var wrongQuestions: [Question] {
        let ids = Set(wrongRecords.filter { !$0.isMastered }.map { $0.questionId })
        return allQuestions.filter { ids.contains($0.id) }
    }

    var dueQuestions: [Question] {
        let dueIds = Set(wrongRecords.filter { $0.isDue }.map { $0.questionId })
        return allQuestions
            .filter { dueIds.contains($0.id) }
            .sorted { q1, q2 in
                let p1 = wrongRecords.first { $0.questionId == q1.id }?.priorityScore ?? 0
                let p2 = wrongRecords.first { $0.questionId == q2.id }?.priorityScore ?? 0
                return p1 > p2
            }
    }

    var masteredCount: Int { wrongRecords.filter { $0.isMastered }.count }
    var wrongTotalCount: Int { wrongRecords.filter { !$0.isMastered }.count }

    // MARK: 初始化
    init() {
        load()
        ensureBuiltInBank()
        refreshDailyIfNeeded()
    }

    // MARK: 答题记录
    func recordAnswer(questionId: UUID, isCorrect: Bool) {
        if let idx = wrongRecords.firstIndex(where: { $0.questionId == questionId }) {
            wrongRecords[idx].update(isCorrect: isCorrect)
        } else if !isCorrect {
            var record = WrongRecord(questionId: questionId)
            record.update(isCorrect: false)
            wrongRecords.append(record)
        }
        save()
    }

    func wrongRecord(for questionId: UUID) -> WrongRecord? {
        wrongRecords.first { $0.questionId == questionId }
    }

    func toggleMastered(_ questionId: UUID) {
        guard let idx = wrongRecords.firstIndex(where: { $0.questionId == questionId }) else { return }
        wrongRecords[idx].isMastered.toggle()
        save()
    }

    func deleteWrongRecord(_ questionId: UUID) {
        wrongRecords.removeAll { $0.questionId == questionId }
        save()
    }

    func clearAllWrongRecords() {
        wrongRecords.removeAll()
        save()
    }

    // MARK: 每日推荐
    func refreshDailyIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastDailyDate,
           Calendar.current.isDate(last, inSameDayAs: today),
           !dailyQuestions.isEmpty { return }
        generateDailyRecommendations()
    }

    func generateDailyRecommendations() {
        let visibleQuestions = allQuestions.filter { !hiddenCategories.contains($0.category) }
        guard !visibleQuestions.isEmpty else {
            dailyQuestions = []
            lastDailyDate = Date()
            saveDailyCache()
            return
        }
        var result: [Question] = []

        // 1. 到期错题优先（最多 15 题，只取可见分类）
        let dueIds = Set(wrongRecords.filter { $0.isDue }.map { $0.questionId })
        let visibleDue = visibleQuestions
            .filter { dueIds.contains($0.id) }
            .sorted { q1, q2 in
                let p1 = wrongRecords.first { $0.questionId == q1.id }?.priorityScore ?? 0
                let p2 = wrongRecords.first { $0.questionId == q2.id }?.priorityScore ?? 0
                return p1 > p2
            }
        result.append(contentsOf: visibleDue.prefix(15))

        // 2. 随机新题补充到 20 题
        if result.count < 20 {
            let existingIds = Set(result.map { $0.id })
            let fillQs = visibleQuestions
                .filter { !existingIds.contains($0.id) }
                .shuffled()
                .prefix(20 - result.count)
            result.append(contentsOf: fillQs)
        }

        dailyQuestions = result.shuffled()
        lastDailyDate = Date()
        saveDailyCache()
    }

    // MARK: 试卷管理
    /// 创建并保存一份新试卷，返回其 id
    @discardableResult
    func saveExamPaper(config: ExamConfig, questions: [Question],
                       scores: [Int]) -> UUID {
        let title = config.autoTitle(actualCount: questions.count)
        let paper = ExamPaper(title: title, config: config,
                              questions: questions, questionScores: scores)
        examPapers.insert(paper, at: 0)   // 最新在前
        save()
        return paper.id
    }

    /// 向已有试卷追加一次作答记录
    func addAttempt(_ attempt: ExamAttempt, toPaperId id: UUID) {
        guard let idx = examPapers.firstIndex(where: { $0.id == id }) else { return }
        examPapers[idx].attempts.append(attempt)
        save()
    }

    func deleteExamPaper(_ paper: ExamPaper) {
        examPapers.removeAll { $0.id == paper.id }
        save()
    }

    // MARK: 题库管理
    func importBank(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bankImport = try decoder.decode(QuestionBankImport.self, from: data)
        let bank = bankImport.toQuestionBank()
        questionBanks.append(bank)
        generateDailyRecommendations()
        save()
    }

    func exportBank(_ bank: QuestionBank) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(bank)
    }

    func exportAllAsBank() throws -> Data {
        let combined = QuestionBank(
            name: "全部题库导出",
            version: "1.0",
            description: "包含所有已启用题库的题目",
            questions: allQuestions
        )
        return try exportBank(combined)
    }

    func deleteBank(_ bank: QuestionBank) {
        questionBanks.removeAll { $0.id == bank.id }
        save()
    }

    func toggleBankEnabled(_ bank: QuestionBank) {
        guard let idx = questionBanks.firstIndex(where: { $0.id == bank.id }) else { return }
        questionBanks[idx].isEnabled.toggle()
        generateDailyRecommendations()
        save()
    }

    func addQuestion(_ question: Question) {
        if let idx = questionBanks.firstIndex(where: { !$0.isBuiltIn }) {
            questionBanks[idx].questions.append(question)
        } else {
            var userBank = QuestionBank(name: "我的题库")
            userBank.questions.append(question)
            questionBanks.append(userBank)
        }
        save()
    }

    // MARK: 内置题库确保
    private func ensureBuiltInBank() {
        if !questionBanks.contains(where: { $0.id == BuiltInQuestions.bankID }) {
            questionBanks.insert(BuiltInQuestions.bank, at: 0)
            save()
        }
    }

    // MARK: 持久化
    private let banksKey      = "quiz_banks_v2"
    private let recordsKey    = "quiz_wrong_records_v2"
    private let dailyQKey     = "quiz_daily_questions_v2"
    private let dailyDKey     = "quiz_daily_date_v2"
    private let papersKey     = "quiz_exam_papers_v1"
    private let hiddenCatKey  = "quiz_hidden_categories_v1"

    func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(questionBanks)           { UserDefaults.standard.set(d, forKey: banksKey) }
        if let d = try? enc.encode(wrongRecords)            { UserDefaults.standard.set(d, forKey: recordsKey) }
        if let d = try? enc.encode(examPapers)              { UserDefaults.standard.set(d, forKey: papersKey) }
        if let d = try? enc.encode(Array(hiddenCategories)) { UserDefaults.standard.set(d, forKey: hiddenCatKey) }
    }

    func load() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let d = UserDefaults.standard.data(forKey: banksKey),
           let b = try? dec.decode([QuestionBank].self, from: d)  { questionBanks = b }
        if let d = UserDefaults.standard.data(forKey: papersKey),
           let p = try? dec.decode([ExamPaper].self, from: d)     { examPapers = p }
        if let d = UserDefaults.standard.data(forKey: recordsKey),
           let r = try? dec.decode([WrongRecord].self, from: d)   { wrongRecords = r }
        if let d = UserDefaults.standard.data(forKey: dailyQKey),
           let q = try? dec.decode([Question].self, from: d)      { dailyQuestions = q }
        if let d = UserDefaults.standard.data(forKey: hiddenCatKey),
           let c = try? dec.decode([String].self, from: d)        { hiddenCategories = Set(c) }
        lastDailyDate = UserDefaults.standard.object(forKey: dailyDKey) as? Date
    }

    private func saveDailyCache() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(dailyQuestions) { UserDefaults.standard.set(d, forKey: dailyQKey) }
        UserDefaults.standard.set(lastDailyDate, forKey: dailyDKey)
    }
}
