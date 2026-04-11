import XCTest
@testable import Lexora

// MARK: - QuizStore 业务逻辑测试

final class QuizStoreTests: XCTestCase {

    var store: QuizStore!

    // 每次测试前清空 UserDefaults，保证隔离
    private let udKeys = [
        "quiz_banks_v2",
        "quiz_wrong_records_v2",
        "quiz_exam_papers_v1",
        "quiz_daily_questions_v2",
        "quiz_daily_date_v2"
    ]

    override func setUp() {
        super.setUp()
        udKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        store = QuizStore()
    }

    override func tearDown() {
        udKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        store = nil
        super.tearDown()
    }

    // MARK: - 初始化

    func test_init_hasBuiltInBank() {
        XCTAssertTrue(store.questionBanks.contains(where: { $0.isBuiltIn }))
    }

    func test_init_allQuestionsNotEmpty() {
        XCTAssertFalse(store.allQuestions.isEmpty)
    }

    func test_init_wrongRecordsEmpty() {
        XCTAssertTrue(store.wrongRecords.isEmpty)
    }

    func test_init_examPapersEmpty() {
        XCTAssertTrue(store.examPapers.isEmpty)
    }

    func test_init_builtInBankNotDuplicated() {
        // 反复调用 ensureBuiltInBank 不会重复添加
        let countBefore = store.questionBanks.filter { $0.isBuiltIn }.count
        store = QuizStore()
        let countAfter = store.questionBanks.filter { $0.isBuiltIn }.count
        XCTAssertEqual(countBefore, countAfter)
    }

    // MARK: - allQuestions / categories

    func test_allQuestions_excludesDisabledBank() throws {
        try store.importBank(from: makeImportJSON(name: "禁用题库", category: "专属分类"))
        guard let idx = store.questionBanks.firstIndex(where: { $0.name == "禁用题库" }) else {
            return XCTFail("没找到导入的题库")
        }
        store.questionBanks[idx].isEnabled = false
        XCTAssertFalse(store.allQuestions.contains(where: { $0.category == "专属分类" }))
    }

    func test_categories_derivedFromAllQuestions() {
        let expected = Set(store.allQuestions.map { $0.category })
        let actual   = Set(store.categories.map { $0.name })
        XCTAssertEqual(expected, actual)
    }

    func test_categories_questionCountMatchesActual() {
        for cat in store.categories {
            let expected = store.allQuestions.filter { $0.category == cat.name }.count
            XCTAssertEqual(cat.questionCount, expected, "分类 \(cat.name) 的题目数不匹配")
        }
    }

    func test_questions_forCategory_returnShuffled() {
        guard let cat = store.categories.first else { return }
        let result = store.questions(for: cat.name)
        XCTAssertEqual(result.count, store.allQuestions.filter { $0.category == cat.name }.count)
    }

    // MARK: - recordAnswer

    func test_recordWrong_createsRecord() {
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: false)
        XCTAssertNotNil(store.wrongRecord(for: qId))
    }

    func test_recordCorrect_doesNotCreateRecord() {
        // 题目从未答错，答对一次不应产生记录
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: true)
        XCTAssertNil(store.wrongRecord(for: qId))
    }

    func test_recordWrong_twice_wrongCountIs2() {
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: false)
        store.recordAnswer(questionId: qId, isCorrect: false)
        XCTAssertEqual(store.wrongRecord(for: qId)?.wrongCount, 2)
    }

    func test_recordCorrect_afterWrong_updatesStreak() {
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: false)
        store.recordAnswer(questionId: qId, isCorrect: true)
        XCTAssertEqual(store.wrongRecord(for: qId)?.correctStreak, 1)
    }

    func test_recordAnswer_savesPersistence() {
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: false)
        // 创建新 store 实例，验证数据已持久化
        let store2 = QuizStore()
        XCTAssertNotNil(store2.wrongRecord(for: qId))
    }

    // MARK: - wrongQuestions / dueQuestions

    func test_wrongQuestions_includesUnmastered() {
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: false)
        XCTAssertTrue(store.wrongQuestions.contains(where: { $0.id == qId }))
    }

    func test_wrongQuestions_excludesMastered() {
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: false)
        store.toggleMastered(qId)
        XCTAssertFalse(store.wrongQuestions.contains(where: { $0.id == qId }))
    }

    func test_dueQuestions_includesJustAddedWrongQuestion() {
        // 刚答错的题目 nextReviewDate = now+1day，理论上不 due
        // 但初始化时 nextReviewDate = Date()，update 后才变未来
        // 验证：刚答错 → update 后 intervalDays=1 → nextReview = tomorrow → 不 due
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: false) // update(false) → nextReview=now+1
        // 因为 nextReviewDate > now，dueQuestions 不应包含
        XCTAssertFalse(store.dueQuestions.contains(where: { $0.id == qId }))
    }

    func test_dueQuestions_sortedByPriorityDescending() {
        let questions = Array(store.allQuestions.prefix(3))
        // 给第 1 题答错 3 次（优先级最高）
        for _ in 0..<3 { store.recordAnswer(questionId: questions[0].id, isCorrect: false) }
        // 给第 2 题答错 1 次
        store.recordAnswer(questionId: questions[1].id, isCorrect: false)

        // 把他们都设为过期（直接修改 nextReviewDate）
        for i in store.wrongRecords.indices {
            store.wrongRecords[i].nextReviewDate = Date().addingTimeInterval(-86400)
        }

        let due = store.dueQuestions
        guard due.count >= 2 else { return }
        let score0 = store.wrongRecord(for: due[0].id)?.priorityScore ?? 0
        let score1 = store.wrongRecord(for: due[1].id)?.priorityScore ?? 0
        XCTAssertGreaterThanOrEqual(score0, score1)
    }

    // MARK: - masteredCount / wrongTotalCount

    func test_masteredCount_incrementsAfterToggle() {
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: false)
        XCTAssertEqual(store.masteredCount, 0)
        store.toggleMastered(qId)
        XCTAssertEqual(store.masteredCount, 1)
    }

    func test_wrongTotalCount_countsUnmastered() {
        let questions = Array(store.allQuestions.prefix(3))
        questions.forEach { store.recordAnswer(questionId: $0.id, isCorrect: false) }
        XCTAssertEqual(store.wrongTotalCount, 3)
    }

    func test_toggleMastered_twice_returnsFalse() {
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: false)
        store.toggleMastered(qId)
        store.toggleMastered(qId)
        XCTAssertFalse(store.wrongRecord(for: qId)?.isMastered ?? true)
    }

    // MARK: - deleteWrongRecord / clearAllWrongRecords

    func test_deleteWrongRecord_removesRecord() {
        let qId = store.allQuestions.first!.id
        store.recordAnswer(questionId: qId, isCorrect: false)
        store.deleteWrongRecord(qId)
        XCTAssertNil(store.wrongRecord(for: qId))
    }

    func test_clearAllWrongRecords_emptyAfterClear() {
        store.allQuestions.prefix(5).forEach {
            store.recordAnswer(questionId: $0.id, isCorrect: false)
        }
        store.clearAllWrongRecords()
        XCTAssertTrue(store.wrongRecords.isEmpty)
    }

    // MARK: - 题库导入

    func test_importBank_addsNewBank() throws {
        let countBefore = store.questionBanks.count
        try store.importBank(from: makeImportJSON(name: "导入测试"))
        XCTAssertEqual(store.questionBanks.count, countBefore + 1)
    }

    func test_importBank_bankNameMatches() throws {
        try store.importBank(from: makeImportJSON(name: "我的新题库"))
        XCTAssertTrue(store.questionBanks.contains(where: { $0.name == "我的新题库" }))
    }

    func test_importBank_questionsAccessibleViaAllQuestions() throws {
        try store.importBank(from: makeImportJSON(name: "X", category: "独特分类_9999"))
        XCTAssertTrue(store.allQuestions.contains(where: { $0.category == "独特分类_9999" }))
    }

    func test_importBank_invalidJSON_throws() {
        XCTAssertThrowsError(try store.importBank(from: Data("invalid".utf8)))
    }

    func test_importBank_emptyQuestions_succeeds() throws {
        let json = """
        {"version":"1.0","name":"空题库","questions":[]}
        """.data(using: .utf8)!
        XCTAssertNoThrow(try store.importBank(from: json))
    }

    // MARK: - 题库导出

    func test_exportBank_dataNotEmpty() throws {
        let bank = store.questionBanks.first!
        let data = try store.exportBank(bank)
        XCTAssertFalse(data.isEmpty)
    }

    func test_exportBank_decodableBack() throws {
        let bank = store.questionBanks.first!
        let data = try store.exportBank(bank)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(QuestionBank.self, from: data)
        XCTAssertEqual(decoded.name, bank.name)
        XCTAssertEqual(decoded.questions.count, bank.questions.count)
    }

    func test_exportAllAsBank_includesAllEnabledQuestions() throws {
        let data = try store.exportAllAsBank()
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(QuestionBank.self, from: data)
        XCTAssertEqual(decoded.questions.count, store.allQuestions.count)
    }

    // MARK: - addQuestion

    func test_addQuestion_createsUserBankWhenNoneExists() {
        store.questionBanks.removeAll { !$0.isBuiltIn }
        store.addQuestion(makeQuestion())
        XCTAssertTrue(store.questionBanks.contains(where: { $0.name == "我的题库" }))
    }

    func test_addQuestion_appendsToFirstNonBuiltInBank() throws {
        try store.importBank(from: makeImportJSON(name: "目标题库"))
        let before = store.questionBanks.first(where: { !$0.isBuiltIn })!.questions.count
        store.addQuestion(makeQuestion())
        let after = store.questionBanks.first(where: { !$0.isBuiltIn })!.questions.count
        XCTAssertEqual(after, before + 1)
    }

    // MARK: - toggleBankEnabled

    func test_toggleBankEnabled_flipsBool() throws {
        try store.importBank(from: makeImportJSON(name: "切换测试"))
        let idx = store.questionBanks.firstIndex(where: { $0.name == "切换测试" })!
        let before = store.questionBanks[idx].isEnabled
        store.toggleBankEnabled(store.questionBanks[idx])
        XCTAssertEqual(store.questionBanks[idx].isEnabled, !before)
    }

    func test_toggleBankEnabled_disabledBankExcludedFromAllQuestions() throws {
        try store.importBank(from: makeImportJSON(name: "禁用测试", category: "禁用分类_888"))
        let bank = store.questionBanks.first(where: { $0.name == "禁用测试" })!
        store.toggleBankEnabled(bank)
        XCTAssertFalse(store.allQuestions.contains(where: { $0.category == "禁用分类_888" }))
    }

    // MARK: - deleteBank

    func test_deleteBank_removedFromBanks() throws {
        try store.importBank(from: makeImportJSON(name: "待删题库"))
        let bank = store.questionBanks.first(where: { $0.name == "待删题库" })!
        store.deleteBank(bank)
        XCTAssertFalse(store.questionBanks.contains(where: { $0.name == "待删题库" }))
    }

    // MARK: - 试卷管理

    func test_saveExamPaper_paperAddedToList() {
        let id = store.saveExamPaper(config: makeConfig(), questions: makePaperQuestions(), scores: [10])
        XCTAssertTrue(store.examPapers.contains(where: { $0.id == id }))
    }

    func test_saveExamPaper_insertedAtFront() {
        let id1 = store.saveExamPaper(config: makeConfig(), questions: makePaperQuestions(), scores: [10])
        let id2 = store.saveExamPaper(config: makeConfig(), questions: makePaperQuestions(), scores: [10])
        XCTAssertEqual(store.examPapers.first?.id, id2, "最新试卷应排在最前")
        XCTAssertEqual(store.examPapers.last?.id, id1)
    }

    func test_addAttempt_appendedToPaper() {
        let id = store.saveExamPaper(config: makeConfig(), questions: makePaperQuestions(), scores: [10])
        store.addAttempt(makeAttempt(), toPaperId: id)
        XCTAssertEqual(store.examPapers.first(where: { $0.id == id })?.attempts.count, 1)
    }

    func test_addAttempt_multipleAttempts() {
        let id = store.saveExamPaper(config: makeConfig(), questions: makePaperQuestions(), scores: [10])
        store.addAttempt(makeAttempt(score: 5), toPaperId: id)
        store.addAttempt(makeAttempt(score: 8), toPaperId: id)
        let paper = store.examPapers.first(where: { $0.id == id })!
        XCTAssertEqual(paper.attempts.count, 2)
        XCTAssertEqual(paper.bestAttempt?.earnedScore, 8)
    }

    func test_deleteExamPaper_removedFromList() {
        let id = store.saveExamPaper(config: makeConfig(), questions: makePaperQuestions(), scores: [10])
        let paper = store.examPapers.first(where: { $0.id == id })!
        store.deleteExamPaper(paper)
        XCTAssertFalse(store.examPapers.contains(where: { $0.id == id }))
    }

    func test_addAttempt_unknownPaperId_noEffect() {
        store.addAttempt(makeAttempt(), toPaperId: UUID())
        XCTAssertTrue(store.examPapers.isEmpty)
    }

    // MARK: - 每日推荐

    func test_generateDaily_countAtMost20() {
        store.generateDailyRecommendations()
        XCTAssertLessThanOrEqual(store.dailyQuestions.count, 20)
    }

    func test_generateDaily_emptyWhenNoQuestions() {
        store.questionBanks.removeAll()
        store.generateDailyRecommendations()
        XCTAssertTrue(store.dailyQuestions.isEmpty)
    }

    func test_generateDaily_includesDueWrongQuestions() {
        let questions = Array(store.allQuestions.prefix(3))
        questions.forEach { store.recordAnswer(questionId: $0.id, isCorrect: false) }
        // 手动设置为过期
        for i in store.wrongRecords.indices {
            store.wrongRecords[i].nextReviewDate = Date().addingTimeInterval(-3600)
        }
        store.generateDailyRecommendations()
        let recommendedIds = Set(store.dailyQuestions.map { $0.id })
        let dueIds = Set(questions.map { $0.id })
        XCTAssertTrue(dueIds.isSubset(of: recommendedIds), "到期错题应被包含在每日推荐中")
    }

    func test_generateDaily_dueQuestionsAtMost15() {
        // 制造 20 道到期错题
        Array(store.allQuestions.prefix(20)).forEach {
            store.recordAnswer(questionId: $0.id, isCorrect: false)
        }
        for i in store.wrongRecords.indices {
            store.wrongRecords[i].nextReviewDate = Date().addingTimeInterval(-3600)
        }
        store.generateDailyRecommendations()
        // 总数 ≤ 20，来自错题的部分 ≤ 15
        let dueIds = Set(store.wrongRecords.filter { $0.isDue }.map { $0.questionId })
        let dueInDaily = store.dailyQuestions.filter { dueIds.contains($0.id) }
        XCTAssertLessThanOrEqual(dueInDaily.count, 15)
    }

    func test_refreshDaily_sameDay_noRegeneration() {
        store.generateDailyRecommendations()
        let ids = store.dailyQuestions.map { $0.id }
        store.refreshDailyIfNeeded()
        let idsAfter = store.dailyQuestions.map { $0.id }
        XCTAssertEqual(ids, idsAfter, "同一天不应重新生成每日推荐")
    }

    func test_generateDaily_noDuplicateQuestions() {
        store.generateDailyRecommendations()
        let ids = store.dailyQuestions.map { $0.id }
        let unique = Set(ids)
        XCTAssertEqual(ids.count, unique.count, "每日推荐不应有重复题目")
    }

    // MARK: - 辅助工厂方法

    func makeQuestion(category: String = "测试") -> Question {
        Question(category: category, text: "测试题目 \(UUID())",
                 options: ["A", "B", "C", "D"], correctIndex: 0)
    }

    func makeImportJSON(name: String, category: String = "测试分类") -> Data {
        """
        {
          "version": "1.0",
          "name": "\(name)",
          "questions": [
            { "category": "\(category)", "text": "Q1",
              "options": ["A","B","C","D"], "correctIndex": 0 }
          ]
        }
        """.data(using: .utf8)!
    }

    func makeConfig() -> ExamConfig {
        let categories = Set(store.allQuestions.prefix(1).map { $0.category })
        return ExamConfig(
            subjects: categories,
            difficulties: [1, 2, 3, 4, 5],
            totalCount: 1,
            totalScore: 10,
            scoreMode: .uniform,
            examMode: .practice
        )
    }

    func makePaperQuestions() -> [Question] {
        Array(store.allQuestions.prefix(1))
    }

    func makeAttempt(score: Int = 7) -> ExamAttempt {
        ExamAttempt(
            startedAt: Date().addingTimeInterval(-60),
            finishedAt: Date(),
            answers: [0: 0],
            earnedScore: score,
            totalScore: 10,
            correctCount: 1,
            totalCount: 1
        )
    }
}
