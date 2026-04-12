import UserNotifications

// MARK: - 前台通知代理（让通知在 App 内也弹出横幅）

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - 通知管理

struct NotificationManager {
    static let reminderID = "lexora_daily_reminder"
    static let testID     = "lexora_test_notification"

    // MARK: 初始化 delegate（在 App 启动时调用一次）
    static func setup() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    // MARK: 权限

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: 调度每日提醒

    /// 调度每日固定时间提醒（先取消旧的同 ID 通知）
    static func schedule(hour: Int, minute: Int, dueQuiz: Int, dueVocab: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        let content = UNMutableNotificationContent()
        content.title = "Lexora"
        content.sound = .default

        if dueQuiz > 0 && dueVocab > 0 {
            content.body = "\(dueQuiz) 道错题 · \(dueVocab) 个单词待复习"
        } else if dueQuiz > 0 {
            content.body = "\(dueQuiz) 道错题待复习，保持学习节奏！"
        } else if dueVocab > 0 {
            content.body = "\(dueVocab) 个单词待复习，坚持就是胜利！"
        } else {
            content.body = "今日学习任务已完成，明天继续加油！"
        }

        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        center.add(request) { error in
            if let error { print("[Notification] schedule error: \(error)") }
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    // MARK: 5 秒测试通知

    static func scheduleTest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [testID])
        let content = UNMutableNotificationContent()
        content.title = "Lexora 测试通知 ✓"
        content.body  = "通知功能正常工作，5 秒后收到此消息"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: testID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: 查询下次触发时间

    static func nextFireDate(hour: Int, minute: Int) -> Date? {
        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute
        return Calendar.current.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime)
    }

    // MARK: App 回到前台时刷新通知内容

    static func rescheduleIfEnabled(dueQuiz: Int, dueVocab: Int) {
        guard UserDefaults.standard.bool(forKey: "reminder_enabled") else { return }
        let hour   = (UserDefaults.standard.object(forKey: "reminder_hour")   as? Int) ?? 20
        let minute = (UserDefaults.standard.object(forKey: "reminder_minute") as? Int) ?? 0
        schedule(hour: hour, minute: minute, dueQuiz: dueQuiz, dueVocab: dueVocab)
    }
}
