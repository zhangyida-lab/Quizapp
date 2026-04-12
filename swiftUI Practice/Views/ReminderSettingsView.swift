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

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            Form {
                toggleSection
                if authStatus == .denied {
                    deniedSection
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
            } else if enabled {
                Text("每天 \(formattedTime) 收到提醒，内容根据待复习数量动态更新")
                    .foregroundColor(.secondary)
            } else {
                Text("开启后每天定时提醒你复习到期的错题和单词")
                    .foregroundColor(.secondary)
            }
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

    private var formattedTime: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: reminderTime)
    }

    private func schedule() {
        NotificationManager.schedule(
            hour: hour,
            minute: minute,
            dueQuiz: store.dueQuestions.count,
            dueVocab: vocabStore.dueWords.count
        )
    }

    private static func defaultTime(h: Int, m: Int) -> Date {
        var comps = DateComponents()
        comps.hour = h; comps.minute = m
        return Calendar.current.date(from: comps) ?? Date()
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView()
    }
    .environmentObject(VocabularyStore())
    .preferredColorScheme(.dark)
}
