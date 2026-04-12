import SwiftUI
import UserNotifications

struct ReminderSettingsView: View {
    @EnvironmentObject private var store: QuizStore
    @EnvironmentObject private var vocabStore: VocabularyStore

    @AppStorage("reminder_enabled") private var enabled = false
    @AppStorage("reminder_hour")    private var hour    = 20
    @AppStorage("reminder_minute")  private var minute  = 0

    @State private var reminderTime: Date = Self.defaultTime(h: 20, m: 0)
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var nextFireDate: Date? = nil
    @State private var testSent = false

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            Form {
                toggleSection
                if authStatus == .denied {
                    deniedSection
                }
                if authStatus == .authorized {
                    testSection
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("学习提醒")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            authStatus = await NotificationManager.authStatus()
            reminderTime = Self.defaultTime(h: hour, m: minute)
            refreshNextFireDate()
        }
    }

    // MARK: 提醒开关 + 时间选择

    private var toggleSection: some View {
        Section {
            // 开关
            Toggle(isOn: Binding(
                get: { enabled },
                set: { newVal in
                    if newVal {
                        Task {
                            authStatus = await NotificationManager.authStatus()
                            if authStatus == .notDetermined {
                                let granted = await NotificationManager.requestPermission()
                                authStatus  = granted ? .authorized : .denied
                                if granted {
                                    enabled = true
                                    schedule()
                                }
                            } else if authStatus == .authorized {
                                enabled = true
                                schedule()
                            }
                            // denied: 不打开开关，下方 footer 提示
                        }
                    } else {
                        enabled = false
                        NotificationManager.cancel()
                        nextFireDate = nil
                    }
                }
            )) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.86, green: 0.55, blue: 0.25))
                            .frame(width: 32, height: 32)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Text("每日学习提醒")
                        .foregroundColor(.white)
                }
            }
            .tint(Color.quizPurpleLight)

            // 时间选择（仅开启时显示）
            if enabled && authStatus == .authorized {
                HStack {
                    Text("提醒时间")
                        .foregroundColor(.white)
                    Spacer()
                    DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .onChange(of: reminderTime) { _, newTime in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                            hour   = comps.hour   ?? 20
                            minute = comps.minute ?? 0
                            schedule()
                        }
                }
            }
        } header: {
            Text("学习提醒")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.quizPurpleLight)
                .textCase(nil)
        } footer: {
            if authStatus == .denied {
                Text("通知权限已关闭，请前往「设置 → 通知 → Lexora」开启")
                    .foregroundColor(.orange)
            } else if enabled, let next = nextFireDate {
                Text("下次提醒：\(next, formatter: Self.dateFormatter)")
                    .foregroundColor(.secondary)
            } else {
                Text("开启后每天定时提醒你复习到期的错题和单词")
                    .foregroundColor(.secondary)
            }
        }
        .listRowBackground(Color.quizCard)
    }

    // MARK: 测试通知

    private var testSection: some View {
        Section {
            Button {
                NotificationManager.scheduleTest()
                testSent = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { testSent = false }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.33, green: 0.78, blue: 0.62))
                            .frame(width: 32, height: 32)
                        Image(systemName: testSent ? "checkmark" : "paperplane.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(testSent ? "已发送，5 秒后查看" : "发送测试通知")
                            .foregroundColor(.white)
                        Text("验证通知是否正常触达")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(authStatus != .authorized)
        } header: {
            Text("调试")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.quizPurpleLight)
                .textCase(nil)
        } footer: {
            Text("点击后将在 5 秒后收到一条测试通知，可以退出 App 后等待，也可留在 App 内等待横幅弹出")
                .foregroundColor(.secondary)
        }
        .listRowBackground(Color.quizCard)
    }

    // MARK: 权限被拒后的引导

    private var deniedSection: some View {
        Section {
            Button {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(Color.quizPurpleLight)
                    Text("前往系统设置开启通知")
                        .foregroundColor(Color.quizPurpleLight)
                }
            }
        }
        .listRowBackground(Color.quizCard)
    }

    // MARK: 辅助

    private func schedule() {
        NotificationManager.schedule(
            hour: hour,
            minute: minute,
            dueQuiz: store.dueQuestions.count,
            dueVocab: vocabStore.dueWords.count
        )
        refreshNextFireDate()
    }

    private func refreshNextFireDate() {
        nextFireDate = enabled ? NotificationManager.nextFireDate(hour: hour, minute: minute) : nil
    }

    private static func defaultTime(h: Int, m: Int) -> Date {
        var comps = DateComponents()
        comps.hour = h; comps.minute = m
        return Calendar.current.date(from: comps) ?? Date()
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MM月dd日 HH:mm"
        return fmt
    }()
}

#Preview {
    NavigationStack {
        ReminderSettingsView()
    }
    .environmentObject(VocabularyStore())
    .preferredColorScheme(.dark)
}
