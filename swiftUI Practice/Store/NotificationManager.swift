import UserNotifications

struct NotificationManager {
    static let reminderID = "lexora_daily_reminder"

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

    // MARK: 调度

    /// 调度每日固定时间提醒（会先取消已有的同 ID 通知）
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
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    // MARK: App 回到前台时刷新通知内容（在 App 入口调用）

    static func rescheduleIfEnabled(dueQuiz: Int, dueVocab: Int) {
        guard UserDefaults.standard.bool(forKey: "reminder_enabled") else { return }
        let hour   = (UserDefaults.standard.object(forKey: "reminder_hour")   as? Int) ?? 20
        let minute = (UserDefaults.standard.object(forKey: "reminder_minute") as? Int) ?? 0
        schedule(hour: hour, minute: minute, dueQuiz: dueQuiz, dueVocab: dueVocab)
    }
}
