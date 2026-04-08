import XCTest
@testable import swiftUI_Practice

// MARK: - SM-2 算法测试

final class WrongRecordTests: XCTestCase {

    var record: WrongRecord!

    override func setUp() {
        super.setUp()
        record = WrongRecord(questionId: UUID())
    }

    // MARK: 初始状态

    func test_init_defaultValues() {
        XCTAssertEqual(record.wrongCount, 0)
        XCTAssertEqual(record.correctStreak, 0)
        XCTAssertEqual(record.intervalDays, 1)
        XCTAssertEqual(record.easeFactor, 2.5, accuracy: 0.001)
        XCTAssertFalse(record.isMastered)
    }

    func test_init_isDueImmediately() {
        // 初始 nextReviewDate = Date()，应立即到期
        XCTAssertTrue(record.isDue)
    }

    // MARK: 答错行为

    func test_wrongAnswer_incrementsWrongCount() {
        record.update(isCorrect: false)
        XCTAssertEqual(record.wrongCount, 1)
    }

    func test_wrongAnswer_resetsStreak() {
        record.update(isCorrect: true)
        record.update(isCorrect: false)
        XCTAssertEqual(record.correctStreak, 0)
    }

    func test_wrongAnswer_resetsIntervalToOne() {
        record.update(isCorrect: true)
        record.update(isCorrect: true) // intervalDays = 3
        record.update(isCorrect: false)
        XCTAssertEqual(record.intervalDays, 1)
    }

    func test_wrongAnswer_decreasesEaseFactor() {
        let before = record.easeFactor
        record.update(isCorrect: false)
        XCTAssertLessThan(record.easeFactor, before)
    }

    func test_wrongAnswer_easeFactorFloorAt1_3() {
        // 连续答错多次，easeFactor 不能低于 1.3
        for _ in 0..<30 {
            record.update(isCorrect: false)
        }
        XCTAssertGreaterThanOrEqual(record.easeFactor, 1.3)
        XCTAssertEqual(record.easeFactor, 1.3, accuracy: 0.001)
    }

    // MARK: 答对行为 — 间隔规则

    func test_correctStreak1_intervalIs1() {
        record.update(isCorrect: true)
        XCTAssertEqual(record.correctStreak, 1)
        XCTAssertEqual(record.intervalDays, 1)
    }

    func test_correctStreak2_intervalIs3() {
        record.update(isCorrect: true)
        record.update(isCorrect: true)
        XCTAssertEqual(record.correctStreak, 2)
        XCTAssertEqual(record.intervalDays, 3)
    }

    func test_correctStreak3_intervalIsEaseFactorMultiplied() {
        record.update(isCorrect: true)
        record.update(isCorrect: true)
        // 第 3 次答对前 intervalDays = 3，easeFactor ≈ 2.5+
        let prevInterval = record.intervalDays
        let prevEase = record.easeFactor
        record.update(isCorrect: true)
        let expected = max(1, Int((Double(prevInterval) * prevEase).rounded()))
        XCTAssertEqual(record.intervalDays, expected)
    }

    func test_correctAnswer_notDueAfterStreak2() {
        record.update(isCorrect: true)
        record.update(isCorrect: true) // intervalDays = 3，nextReview = now+3天
        XCTAssertFalse(record.isDue)
    }

    func test_correctAnswer_easeFactorIncreasesOrStays() {
        let before = record.easeFactor
        record.update(isCorrect: true)
        // quality=4 时：newEF = ef + 0.1 - 1*(0.08+0.02) = ef + 0.0，不变
        // 实际上对于 quality=4: 0.1 - (5-4)*(0.08+(5-4)*0.02) = 0.1 - 0.1 = 0
        XCTAssertGreaterThanOrEqual(record.easeFactor, before - 0.001)
    }

    // MARK: 答对/答错交替

    func test_streakResetsAfterWrong() {
        record.update(isCorrect: true)
        record.update(isCorrect: true)
        record.update(isCorrect: false)
        record.update(isCorrect: true)  // 重新开始
        XCTAssertEqual(record.correctStreak, 1)
        XCTAssertEqual(record.intervalDays, 1)
    }

    // MARK: isDue

    func test_isDue_falseWhenMastered() {
        record.isMastered = true
        XCTAssertFalse(record.isDue)
    }

    func test_isDue_falseAfterFutureReviewDate() {
        record.update(isCorrect: true)
        record.update(isCorrect: true) // nextReview = now + 3 days
        XCTAssertFalse(record.isDue)
    }

    // MARK: priorityScore

    func test_priorityScore_negativeWhenMastered() {
        record.isMastered = true
        XCTAssertLessThan(record.priorityScore, 0)
    }

    func test_priorityScore_higherWithMoreWrongCount() {
        var r1 = WrongRecord(questionId: UUID())
        var r2 = WrongRecord(questionId: UUID())
        r1.update(isCorrect: false)              // wrongCount = 1
        r2.update(isCorrect: false)
        r2.update(isCorrect: false)              // wrongCount = 2
        XCTAssertGreaterThan(r2.priorityScore, r1.priorityScore)
    }

    func test_priorityScore_urgencyBonusWhenStreakIsZero() {
        // correctStreak == 0 时，urgency = 3，应计入 priorityScore
        record.update(isCorrect: false) // wrongCount=1, streak=0
        let scoreWithUrgency = record.priorityScore

        var r2 = WrongRecord(questionId: UUID())
        r2.update(isCorrect: false)
        r2.update(isCorrect: true)  // wrongCount=1, streak=1（无 urgency）
        let scoreWithoutUrgency = r2.priorityScore

        XCTAssertGreaterThan(scoreWithUrgency, scoreWithoutUrgency)
    }

    // MARK: masteryLevel

    func test_masteryLevel_waitWhenNoStreak() {
        XCTAssertEqual(record.masteryLevel, "待巩固")
    }

    func test_masteryLevel_improvingAtStreak1() {
        record.update(isCorrect: true)
        XCTAssertEqual(record.masteryLevel, "进步中")
    }

    func test_masteryLevel_improvingAtStreak2() {
        record.update(isCorrect: true)
        record.update(isCorrect: true)
        XCTAssertEqual(record.masteryLevel, "进步中")
    }

    func test_masteryLevel_fluentAtStreak3() {
        record.update(isCorrect: true)
        record.update(isCorrect: true)
        record.update(isCorrect: true)
        XCTAssertEqual(record.masteryLevel, "较熟练")
    }

    func test_masteryLevel_masteredWhenFlagged() {
        record.isMastered = true
        XCTAssertEqual(record.masteryLevel, "已掌握")
    }

    // MARK: nextReviewDate

    func test_nextReviewDate_inFutureAfterCorrect() {
        record.update(isCorrect: true)
        record.update(isCorrect: true) // intervalDays = 3
        XCTAssertGreaterThan(record.nextReviewDate, Date())
    }

    func test_nextReviewDate_aproximatelyNowPlusInterval() {
        record.update(isCorrect: true)
        record.update(isCorrect: true) // intervalDays = 3
        let expected = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        XCTAssertEqual(record.nextReviewDate.timeIntervalSince1970,
                       expected.timeIntervalSince1970, accuracy: 5)
    }
}
