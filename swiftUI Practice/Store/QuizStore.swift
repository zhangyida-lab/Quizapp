import Foundation
import SwiftUI
import SwiftData

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
    private let modelContext: ModelContext

    // MARK: 计算属性
    var allQuestions: [Question] {
        questionBanks.filter { $0.isEnabled }.flatMap { $0.questions }
    }

    var allCategories: [CategoryInfo] {
        let grouped = Dictionary(grouping: allQuestions, by: { $0.category })
        return grouped
            .map { CategoryInfo(id: $0.key, name: $0.key, questionCount: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

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
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        load()
        migrateFromUserDefaultsIfNeeded()
        ensureBuiltInBank()
        refreshDailyIfNeeded()
    }

    // MARK: 答题记录
    func recordAnswer(questionId: UUID, isCorrect: Bool) {
        let cfg = AlgorithmSettingsStore.loadConfig()
        if let idx = wrongRecords.firstIndex(where: { $0.questionId == questionId }) {
            if cfg.schedulerType == .fsrs {
                wrongRecords[idx].updateFSRS(isCorrect: isCorrect,
                                             targetRetention: cfg.fsrsTargetRetention)
            } else {
                wrongRecords[idx].update(isCorrect: isCorrect,
                                         wrongResetDays: cfg.sm2WrongResetDays,
                                         minEaseFactor: cfg.sm2MinEaseFactor,
                                         easePenalty: cfg.sm2EasePenalty)
            }
        } else if !isCorrect {
            var record = WrongRecord(questionId: questionId)
            if cfg.schedulerType == .fsrs {
                record.updateFSRS(isCorrect: false, targetRetention: cfg.fsrsTargetRetention)
            } else {
                record.update(isCorrect: false,
                              wrongResetDays: cfg.sm2WrongResetDays,
                              minEaseFactor: cfg.sm2MinEaseFactor,
                              easePenalty: cfg.sm2EasePenalty)
            }
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
        let cfg = AlgorithmSettingsStore.loadConfig()
        let total = cfg.dailyQuestionCount
        let maxDue = max(1, Int(Double(total) * cfg.dueQuestionMaxRatio))

        let visibleQuestions = allQuestions.filter { !hiddenCategories.contains($0.category) }
        guard !visibleQuestions.isEmpty else {
            dailyQuestions = []
            lastDailyDate = Date()
            saveDailyCache()
            return
        }

        // 1. 到期错题（按优先级排序，取 maxDue 上限）
        let dueIds = Set(wrongRecords.filter { $0.isDue }.map { $0.questionId })
        let visibleDue = visibleQuestions
            .filter { dueIds.contains($0.id) }
            .sorted { q1, q2 in
                let p1 = wrongRecords.first { $0.questionId == q1.id }?.priorityScore ?? 0
                let p2 = wrongRecords.first { $0.questionId == q2.id }?.priorityScore ?? 0
                return p1 > p2
            }
        var result = Array(visibleDue.prefix(maxDue))

        // 2. 补充题（不足 total 时填满）
        if result.count < total {
            let existingIds = Set(result.map { $0.id })
            let candidates = visibleQuestions.filter { !existingIds.contains($0.id) && !dueIds.contains($0.id) }
            let needed = total - result.count

            if cfg.useWeightedFill {
                // 加权随机：错误率高、从未答对的题优先
                let wrongIdMap = Dictionary(uniqueKeysWithValues: wrongRecords.map { ($0.questionId, $0) })
                let weighted = candidates
                    .map { q -> (Question, Double) in
                        let rec = wrongIdMap[q.id]
                        let weight: Double
                        if let r = rec {
                            // 答对过但错误率高的题给更高权重
                            let errorRate = r.correctStreak == 0 ? 1.0 : Double(r.wrongCount) / Double(r.wrongCount + r.correctStreak)
                            weight = 1.0 + errorRate * 3.0
                        } else {
                            weight = 1.0   // 从未做过的题基础权重
                        }
                        return (q, weight)
                    }
                    .sorted { $0.1 > $1.1 }  // 权重高的排前面

                // 加权随机采样
                let fillQs = weightedSample(from: weighted, count: needed)
                result.append(contentsOf: fillQs)
            } else {
                result.append(contentsOf: candidates.shuffled().prefix(needed))
            }
        }

        dailyQuestions = result.shuffled()
        lastDailyDate = Date()
        saveDailyCache()
    }

    /// 加权随机采样（权重越高被选中概率越大）
    private func weightedSample(from items: [(Question, Double)], count: Int) -> [Question] {
        var pool = items
        var selected: [Question] = []
        let needed = min(count, pool.count)
        for _ in 0..<needed {
            let totalWeight = pool.reduce(0) { $0 + $1.1 }
            guard totalWeight > 0 else { break }
            var r = Double.random(in: 0..<totalWeight)
            for (i, (q, w)) in pool.enumerated() {
                r -= w
                if r <= 0 {
                    selected.append(q)
                    pool.remove(at: i)
                    break
                }
            }
        }
        return selected
    }

    // MARK: 试卷管理
    @discardableResult
    func saveExamPaper(config: ExamConfig, questions: [Question],
                       scores: [Int]) -> UUID {
        let title = config.autoTitle(actualCount: questions.count)
        let paper = ExamPaper(title: title, config: config,
                              questions: questions, questionScores: scores)
        examPapers.insert(paper, at: 0)
        save()
        return paper.id
    }

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

    func exportBankForSharing(_ bank: QuestionBank) async throws -> Data {
        var uploadedBank = bank
        for i in uploadedBank.questions.indices {
            guard let img = uploadedBank.questions[i].image,
                  img.type == .file else { continue }
            let fileURL   = URL(fileURLWithPath: img.value)
            let remoteURL = try await CloudinaryUploader.upload(fileURL: fileURL)
            uploadedBank.questions[i].image = QuestionImageData(type: .url, value: remoteURL)
        }
        return try exportBank(uploadedBank)
    }

    func exportAllAsBankForSharing() async throws -> Data {
        let combined = QuestionBank(
            name: "全部题库导出",
            version: "1.0",
            description: "包含所有已启用题库的题目",
            questions: allQuestions
        )
        return try await exportBankForSharing(combined)
    }

    func shareBankAsURL(_ bank: QuestionBank) async throws -> String {
        let jsonData = try await exportBankForSharing(bank)
        return try await CloudinaryUploader.uploadJSON(jsonData, name: bank.name)
    }

    func shareAllBanksAsURL() async throws -> String {
        let jsonData = try await exportAllAsBankForSharing()
        return try await CloudinaryUploader.uploadJSON(jsonData, name: "全部题库")
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

    func renameCategory(from oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != oldName else { return }
        for bi in questionBanks.indices {
            for qi in questionBanks[bi].questions.indices
                where questionBanks[bi].questions[qi].category == oldName {
                questionBanks[bi].questions[qi].category = trimmed
            }
        }
        if hiddenCategories.contains(oldName) {
            hiddenCategories.remove(oldName)
            hiddenCategories.insert(trimmed)
        }
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

    // MARK: - 持久化（SwiftData）

    func save() {
        saveBanks()
        saveRecords()
        savePapers()
        saveSettings()
        try? modelContext.save()
    }

    private func load() {
        let dec = makeDecoder()

        // 题库（按创建时间升序）
        let banksDesc = FetchDescriptor<QuestionBankEntity>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        questionBanks = ((try? modelContext.fetch(banksDesc)) ?? []).map { $0.toStruct() }

        // 错题记录
        let recordsDesc = FetchDescriptor<WrongRecordEntity>()
        wrongRecords = ((try? modelContext.fetch(recordsDesc)) ?? []).map { $0.toStruct() }

        // 试卷（最新在前）
        let papersDesc = FetchDescriptor<ExamPaperEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        examPapers = ((try? modelContext.fetch(papersDesc)) ?? []).compactMap { $0.toStruct() }

        // 应用设置
        let settingsDesc = FetchDescriptor<AppSettingsEntity>()
        if let settings = (try? modelContext.fetch(settingsDesc))?.first {
            if let cats = try? dec.decode([String].self, from: settings.hiddenCatsData) {
                hiddenCategories = Set(cats)
            }
            if let data = settings.dailyQuestionsData,
               let questions = try? dec.decode([Question].self, from: data) {
                dailyQuestions = questions
            }
            lastDailyDate = settings.lastDailyDate
        }
    }

    private func saveDailyCache() {
        let enc = makeEncoder()
        let settings = getOrCreateSettings()
        settings.dailyQuestionsData = try? enc.encode(dailyQuestions)
        settings.lastDailyDate      = lastDailyDate
        try? modelContext.save()
    }

    // MARK: SwiftData 同步辅助

    private func saveBanks() {
        let existing    = fetchAll(QuestionBankEntity.self)
        let existingMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let currentIDs  = Set(questionBanks.map { $0.id })
        for entity in existing where !currentIDs.contains(entity.id) {
            modelContext.delete(entity)
        }
        for bank in questionBanks {
            if let entity = existingMap[bank.id] { entity.syncFrom(bank) }
            else { modelContext.insert(QuestionBankEntity(bank: bank)) }
        }
    }

    private func saveRecords() {
        let existing    = fetchAll(WrongRecordEntity.self)
        let existingMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let currentIDs  = Set(wrongRecords.map { $0.id })
        for entity in existing where !currentIDs.contains(entity.id) {
            modelContext.delete(entity)
        }
        for record in wrongRecords {
            if let entity = existingMap[record.id] { entity.syncFrom(record) }
            else { modelContext.insert(WrongRecordEntity(record: record)) }
        }
    }

    private func savePapers() {
        let existing    = fetchAll(ExamPaperEntity.self)
        let existingMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let currentIDs  = Set(examPapers.map { $0.id })
        for entity in existing where !currentIDs.contains(entity.id) {
            modelContext.delete(entity)
        }
        for paper in examPapers {
            if let entity = existingMap[paper.id] { entity.syncFrom(paper) }
            else { modelContext.insert(ExamPaperEntity(paper: paper)) }
        }
    }

    private func saveSettings() {
        let enc      = makeEncoder()
        let settings = getOrCreateSettings()
        settings.hiddenCatsData = (try? enc.encode(Array(hiddenCategories))) ?? Data()
        settings.lastDailyDate  = lastDailyDate
    }

    private func getOrCreateSettings() -> AppSettingsEntity {
        let desc = FetchDescriptor<AppSettingsEntity>()
        if let existing = (try? modelContext.fetch(desc))?.first { return existing }
        let settings = AppSettingsEntity()
        modelContext.insert(settings)
        return settings
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? modelContext.fetch(FetchDescriptor<T>())) ?? []
    }

    // MARK: 备份恢复

    func restoreFromBackup(_ backup: LexoraBackup) {
        let builtInBanks = questionBanks.filter { $0.isBuiltIn }
        questionBanks    = builtInBanks + backup.questionBanks
        wrongRecords     = backup.wrongRecords
        examPapers       = backup.examPapers
        hiddenCategories = Set(backup.hiddenCategories)
        save()
        generateDailyRecommendations()
    }

    // MARK: UserDefaults → SwiftData 一次性迁移

    private func migrateFromUserDefaultsIfNeeded() {
        // SwiftData 已有数据（非首次启动），跳过迁移
        guard questionBanks.isEmpty else { return }

        let ud  = UserDefaults.standard
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601

        let banksKey     = "quiz_banks_v2"
        let recordsKey   = "quiz_wrong_records_v2"
        let papersKey    = "quiz_exam_papers_v1"
        let hiddenCatKey = "quiz_hidden_categories_v1"
        let dailyQKey    = "quiz_daily_questions_v2"
        let dailyDKey    = "quiz_daily_date_v2"

        // UserDefaults 也没有数据（全新安装），不需迁移
        guard ud.data(forKey: banksKey) != nil else { return }

        if let d = ud.data(forKey: banksKey),
           let banks = try? dec.decode([QuestionBank].self, from: d) {
            questionBanks = banks
        }
        if let d = ud.data(forKey: recordsKey),
           let records = try? dec.decode([WrongRecord].self, from: d) {
            wrongRecords = records
        }
        if let d = ud.data(forKey: papersKey),
           let papers = try? dec.decode([ExamPaper].self, from: d) {
            examPapers = papers
        }
        if let d = ud.data(forKey: hiddenCatKey),
           let cats = try? dec.decode([String].self, from: d) {
            hiddenCategories = Set(cats)
        }
        if let d = ud.data(forKey: dailyQKey),
           let questions = try? dec.decode([Question].self, from: d) {
            dailyQuestions = questions
        }
        lastDailyDate = ud.object(forKey: dailyDKey) as? Date

        // 持久化到 SwiftData，清除 UserDefaults
        save()
        [banksKey, recordsKey, papersKey, hiddenCatKey, dailyQKey, dailyDKey]
            .forEach { ud.removeObject(forKey: $0) }
    }

    // MARK: JSON 辅助
    private func makeEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    private func makeDecoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }
}
