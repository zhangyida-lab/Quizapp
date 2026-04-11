import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var algoStore: AlgorithmSettingsStore
    @EnvironmentObject private var store: QuizStore
    @EnvironmentObject private var vocabStore: VocabularyStore

    @State private var wechatCopied = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            Form {
                algorithmSection
                feedbackSection
                aboutSection
                legalSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: 算法设置
    private var algorithmSection: some View {
        Section {
            NavigationLink(destination: AlgorithmSettingsView()) {
                HStack(spacing: 14) {
                    SettingsIcon(systemName: "slider.horizontal.3", color: Color.quizPurple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("算法设置")
                            .foregroundColor(.white)
                        Text("每日推荐、词汇学习、SM-2、试卷生成")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            NavigationLink(destination: HelpView()) {
                HStack(spacing: 14) {
                    SettingsIcon(systemName: "questionmark.circle.fill", color: Color(red: 0.20, green: 0.60, blue: 0.86))
                    Text("使用帮助")
                        .foregroundColor(.white)
                }
            }
        } header: {
            SettingsSectionHeader("学习算法")
        }
        .listRowBackground(Color.quizCard)
    }

    // MARK: 反馈与联系
    private var feedbackSection: some View {
        Section {
            // 邮件反馈
            Link(destination: URL(string: "mailto:acboo2020@gmail.com?subject=Lexora%20反馈&body=App%20版本：\(appVersion)%20(\(buildNumber))%0A设备：\(UIDevice.current.model)%20iOS%20\(UIDevice.current.systemVersion)%0A%0A问题描述：")!) {
                HStack(spacing: 14) {
                    SettingsIcon(systemName: "envelope.fill", color: Color(red: 0.20, green: 0.60, blue: 0.86))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("发送邮件反馈")
                            .foregroundColor(.white)
                        Text("acboo2020@gmail.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // 微信
            Button {
                UIPasteboard.general.string = "danshengshuo"
                wechatCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    wechatCopied = false
                }
            } label: {
                HStack(spacing: 14) {
                    SettingsIcon(systemName: "message.fill", color: Color(red: 0.13, green: 0.75, blue: 0.37))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("微信联系开发者")
                            .foregroundColor(.white)
                        Text("danshengshuo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(wechatCopied ? "已复制" : "点击复制")
                        .font(.caption)
                        .foregroundColor(wechatCopied ? Color.quizGreen : .secondary)
                        .animation(.easeInOut(duration: 0.2), value: wechatCopied)
                }
            }
        } header: {
            SettingsSectionHeader("反馈与联系")
        }
        .listRowBackground(Color.quizCard)
    }

    // MARK: 关于本应用
    private var aboutSection: some View {
        Section {
            // App 信息
            HStack(spacing: 14) {
                SettingsIcon(systemName: "app.fill", color: Color(red: 0.37, green: 0.36, blue: 0.90))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lexora")
                        .foregroundColor(.white)
                    Text("版本 \(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // 功能简介
            HStack(spacing: 14) {
                SettingsIcon(systemName: "info.circle.fill", color: Color(red: 0.20, green: 0.60, blue: 0.86))
                VStack(alignment: .leading, spacing: 4) {
                    Text("功能介绍")
                        .foregroundColor(.white)
                    Text("Lexora 包含两个核心模块：**答题**（知识竞答、错题本、试卷生成）和**词汇**（闪卡记忆、选词练习、生词本）。所有数据本地存储，不上传任何服务器。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)

            // 开发者
            HStack(spacing: 14) {
                SettingsIcon(systemName: "person.fill", color: Color(red: 0.33, green: 0.78, blue: 0.62))
                Text("开发者")
                    .foregroundColor(.white)
                Spacer()
                Text("zhangyida-lab")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }

            // 数据统计
            HStack(spacing: 14) {
                SettingsIcon(systemName: "chart.bar.fill", color: Color(red: 0.86, green: 0.55, blue: 0.25))
                Text("当前数据")
                    .foregroundColor(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(store.allQuestions.count) 道题 · \(vocabStore.allWords.count) 个词")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("\(store.masteredCount) 题已掌握 · \(vocabStore.masteredCount) 词已掌握")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

        } header: {
            SettingsSectionHeader("关于 Lexora")
        }
        .listRowBackground(Color.quizCard)
    }

    // MARK: 法律 & 隐私
    private var legalSection: some View {
        Section {
            // 隐私政策
            Link(destination: URL(string: "https://zhangyida-lab.github.io/lexora-privacy/")!) {
                HStack(spacing: 14) {
                    SettingsIcon(systemName: "hand.raised.fill", color: Color(red: 0.53, green: 0.40, blue: 0.88))
                    Text("隐私政策")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // 数据说明
            HStack(spacing: 14) {
                SettingsIcon(systemName: "lock.fill", color: Color(red: 0.33, green: 0.62, blue: 0.93))
                VStack(alignment: .leading, spacing: 2) {
                    Text("数据存储说明")
                        .foregroundColor(.white)
                    Text("所有题库、词库、学习记录均仅保存在本设备，卸载应用后数据将被清除。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)

        } header: {
            SettingsSectionHeader("隐私与法律")
        }
        .listRowBackground(Color.quizCard)
    }
}

// MARK: - 子组件

private struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

private struct SettingsSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color.quizPurpleLight)
            .textCase(nil)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(AlgorithmSettingsStore())
    .environmentObject(VocabularyStore())
    .environmentObject(QuizStore(modelContext: try! ModelContainer(for:
        QuestionBankEntity.self, WrongRecordEntity.self, ExamPaperEntity.self,
        AppSettingsEntity.self).mainContext))
    .preferredColorScheme(.dark)
}
