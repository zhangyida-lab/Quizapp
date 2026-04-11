import SwiftUI
import SwiftData

// MARK: - 算法设置主页

struct AlgorithmSettingsView: View {
    @EnvironmentObject private var algoStore: AlgorithmSettingsStore
    @EnvironmentObject private var store: QuizStore
    @EnvironmentObject private var vocabStore: VocabularyStore
    @State private var showResetConfirm = false

    private var cfg: Binding<AlgorithmConfig> { $algoStore.config }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            Form {
                dailyQuizSection
                dailyWordSection
                sm2Section
                examSection
                resetSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("算法设置")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("恢复默认设置？", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("恢复默认", role: .destructive) {
                algoStore.resetToDefaults()
                store.generateDailyRecommendations()
                vocabStore.generateDailyWords()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有算法参数将恢复为出厂默认值，当前设置不可撤销。")
        }
    }

    // MARK: 每日题目推荐
    private var dailyQuizSection: some View {
        Section {
            // 每日题数
            HStack {
                Label("每日题数", systemImage: "doc.text.fill")
                    .foregroundColor(.white)
                Spacer()
                Stepper("\(algoStore.config.dailyQuestionCount) 题",
                        value: cfg.dailyQuestionCount,
                        in: 10...40, step: 5)
                    .foregroundColor(Color.quizPurpleLight)
                    .fixedSize()
            }

            // 错题占比上限
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("错题占比上限", systemImage: "xmark.circle.fill")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(algoStore.config.dueQuestionMaxRatio * 100))%")
                        .foregroundColor(Color.quizPurpleLight)
                        .monospacedDigit()
                }
                Slider(value: cfg.dueQuestionMaxRatio, in: 0.3...1.0, step: 0.05)
                    .tint(Color.quizPurple)
                Text("每日推荐中，到期错题最多占 \(Int(algoStore.config.dueQuestionMaxRatio * 100))%，其余用新题补充")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 补充题策略
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: cfg.useWeightedFill) {
                    Label("薄弱点加权补充", systemImage: "chart.bar.fill")
                        .foregroundColor(.white)
                }
                .tint(Color.quizPurple)
                Text(algoStore.config.useWeightedFill
                     ? "错误率高的题有更大概率被补充进来"
                     : "从剩余题目中完全随机补充")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        } header: {
            SectionHeader(icon: "calendar.badge.clock", title: "每日题目推荐")
        }
        .listRowBackground(Color.quizCard)
    }

    // MARK: 词汇学习
    private var dailyWordSection: some View {
        Section {
            // 每日单词数
            HStack {
                Label("每日单词数", systemImage: "text.book.closed.fill")
                    .foregroundColor(.white)
                Spacer()
                Stepper("\(algoStore.config.dailyWordCount) 词",
                        value: cfg.dailyWordCount,
                        in: 10...50, step: 5)
                    .foregroundColor(Color.quizPurpleLight)
                    .fixedSize()
            }

            // 新词比例
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("新词比例", systemImage: "plus.circle.fill")
                        .foregroundColor(.white)
                    Spacer()
                    let newCount = max(1, Int(Double(algoStore.config.dailyWordCount) * algoStore.config.newWordRatio))
                    let revCount = algoStore.config.dailyWordCount - newCount
                    Text("新词 \(newCount) · 复习 \(revCount)")
                        .foregroundColor(Color.quizPurpleLight)
                        .font(.system(size: 13))
                        .monospacedDigit()
                }
                Slider(value: cfg.newWordRatio, in: 0.0...0.7, step: 0.1)
                    .tint(Color.quizPurple)
                Text("新词占每日单词总数的 \(Int(algoStore.config.newWordRatio * 100))%，其余为待复习单词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        } header: {
            SectionHeader(icon: "brain.head.profile", title: "词汇学习")
        }
        .listRowBackground(Color.quizCard)
    }

    // MARK: SM-2 间隔参数
    private var sm2Section: some View {
        Section {
            // 答错重置天数
            HStack {
                Label("答错重置间隔", systemImage: "arrow.counterclockwise")
                    .foregroundColor(.white)
                Spacer()
                Stepper("\(algoStore.config.sm2WrongResetDays) 天",
                        value: cfg.sm2WrongResetDays,
                        in: 1...3)
                    .foregroundColor(Color.quizPurpleLight)
                    .fixedSize()
            }

            // 最低难度系数
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("最低难度系数", systemImage: "slider.horizontal.3")
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.1f", algoStore.config.sm2MinEaseFactor))
                        .foregroundColor(Color.quizPurpleLight)
                        .monospacedDigit()
                }
                Slider(value: cfg.sm2MinEaseFactor, in: 1.2...2.0, step: 0.1)
                    .tint(Color.quizPurple)
                Text("难度系数越低，复习频率越高；建议保持 1.3")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 答错降幅
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("答错难度降幅", systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.2f", algoStore.config.sm2EasePenalty))
                        .foregroundColor(Color.quizPurpleLight)
                        .monospacedDigit()
                }
                Slider(value: cfg.sm2EasePenalty, in: 0.1...0.4, step: 0.05)
                    .tint(Color.quizPurple)
                Text("答错后难度系数减少此值，越大惩罚越重")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        } header: {
            SectionHeader(icon: "clock.arrow.2.circlepath", title: "SM-2 间隔参数（题目 & 单词共用）")
        } footer: {
            Text("SM-2 是一种间隔重复算法：答对次数越多，下次复习时间间隔越长；答错则缩短间隔并增加复习频率。")
                .foregroundColor(.secondary)
        }
        .listRowBackground(Color.quizCard)
    }

    // MARK: 试卷生成
    private var examSection: some View {
        Section {
            // 默认题数
            HStack {
                Label("默认出题数", systemImage: "doc.plaintext.fill")
                    .foregroundColor(.white)
                Spacer()
                Stepper("\(algoStore.config.examDefaultCount) 题",
                        value: cfg.examDefaultCount,
                        in: 5...50, step: 5)
                    .foregroundColor(Color.quizPurpleLight)
                    .fixedSize()
            }

            // 难度分布
            VStack(alignment: .leading, spacing: 8) {
                Label("难度分布预设", systemImage: "chart.pie.fill")
                    .foregroundColor(.white)
                Picker("难度分布", selection: cfg.examDifficulty) {
                    ForEach(AlgorithmConfig.ExamDifficultyPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                Text(algoStore.config.examDifficulty.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        } header: {
            SectionHeader(icon: "doc.text.fill", title: "试卷生成")
        }
        .listRowBackground(Color.quizCard)
    }

    // MARK: 重置
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Label("恢复默认设置", systemImage: "arrow.clockwise")
                    Spacer()
                }
            }
        }
        .listRowBackground(Color.quizCard)
    }
}

// MARK: - Section 标题
private struct SectionHeader: View {
    let icon: String
    let title: String
    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.quizPurpleLight)
            .textCase(nil)
    }
}

#Preview {
    NavigationStack {
        AlgorithmSettingsView()
    }
    .environmentObject(AlgorithmSettingsStore())
    .environmentObject(VocabularyStore())
    .environmentObject(QuizStore(modelContext: try! ModelContainer(for:
        QuestionBankEntity.self, WrongRecordEntity.self, ExamPaperEntity.self,
        AppSettingsEntity.self).mainContext))
    .preferredColorScheme(.dark)
}
