import SwiftUI
import QuickLook

// MARK: - 试卷配置页

struct ExamConfigView: View {
    @EnvironmentObject private var store: QuizStore
    @Environment(\.dismiss) private var dismiss

    // 配置状态
    @State private var selectedSubjects: Set<String> = []
    @State private var selectedDifficulties: Set<Int> = [1, 2, 3, 4, 5]
    @State private var totalCount: Int = 10
    @State private var totalScore: Int = 100
    @State private var scoreMode: ExamConfig.ScoreMode = .uniform
    @State private var examMode: ExamConfig.ExamMode   = .practice

    // 导航
    @State private var navigateToExam = false
    @State private var generatedQuestions: [Question] = []
    @State private var generatedScores: [Int] = []

    // 空白试卷 PDF
    @State private var isGenBlankPDF  = false
    @State private var blankPDFURL: URL? = nil
    @State private var showBlankPDF   = false

    // MARK: 计算属性
    var config: ExamConfig {
        ExamConfig(
            subjects: selectedSubjects,
            difficulties: selectedDifficulties,
            totalCount: totalCount,
            totalScore: totalScore,
            scoreMode: scoreMode,
            examMode: examMode
        )
    }

    var availableCount: Int { config.availableCount(from: store.allQuestions) }

    var canGenerate: Bool {
        !selectedSubjects.isEmpty && !selectedDifficulties.isEmpty && availableCount >= 1
    }

    var actualCount: Int { min(totalCount, availableCount) }

    var scorePerQ: String {
        guard actualCount > 0 else { return "—" }
        switch scoreMode {
        case .uniform:
            let base = totalScore / actualCount
            let rem  = totalScore - base * actualCount
            return rem == 0 ? "\(base) 分/题" : "约 \(base)-\(base + rem) 分/题"
        case .byDifficulty:
            return "1-2★: 低分  3★: 中分  4-5★: 高分"
        }
    }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    subjectSection
                    difficultySection
                    countSection
                    scoreSection
                    examModeSection
                    summaryCard
                    startButton
                    Spacer(minLength: 40)
                }
                .padding(.top, 16).padding(.bottom, 40).padding(.horizontal, 16)
            }
        }
        .navigationTitle("生成试卷")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToExam) {
            ExamContainerView(
                config: config,
                questions: generatedQuestions,
                questionScores: generatedScores
            )
        }
        .sheet(isPresented: $showBlankPDF) {
            if let url = blankPDFURL { PDFPreviewView(url: url) }
        }
        .onAppear {
            // 默认全选科目
            if selectedSubjects.isEmpty {
                selectedSubjects = Set(store.categories.map { $0.name })
            }
        }
    }

    // MARK: - 科目选择
    var subjectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("选择科目", icon: "square.grid.2x2.fill") {
                Button {
                    if selectedSubjects.count == store.categories.count {
                        selectedSubjects.removeAll()
                    } else {
                        selectedSubjects = Set(store.categories.map { $0.name })
                    }
                } label: {
                    Text(selectedSubjects.count == store.categories.count ? "取消全选" : "全选")
                        .font(.system(size: 12)).foregroundColor(Color.quizPurpleLight)
                }
                .buttonStyle(PlainButtonStyle())
            }

            FlowLayout(spacing: 10) {
                ForEach(store.categories) { cat in
                    let selected = selectedSubjects.contains(cat.name)
                    Button {
                        if selected { selectedSubjects.remove(cat.name) }
                        else        { selectedSubjects.insert(cat.name) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.icon).font(.system(size: 11))
                            Text(cat.name).font(.system(size: 13, weight: .medium))
                            Text("(\(cat.questionCount))").font(.system(size: 11))
                        }
                        .foregroundColor(selected ? .white : cat.color)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(selected ? cat.color : cat.color.opacity(0.15))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(cat.color.opacity(selected ? 0 : 0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .configCard()
    }

    // MARK: - 难度选择
    var difficultySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("难度筛选", icon: "star.fill")

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { d in
                    let selected = selectedDifficulties.contains(d)
                    Button {
                        if selected { selectedDifficulties.remove(d) }
                        else        { selectedDifficulties.insert(d) }
                    } label: {
                        VStack(spacing: 5) {
                            HStack(spacing: 2) {
                                ForEach(0..<d, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(selected ? .white : .yellow)
                                }
                            }
                            Text(diffLabel(d))
                                .font(.system(size: 10))
                                .foregroundColor(selected ? .white : .secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(selected ? Color.quizPurple : Color.quizCard)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selected ? Color.quizPurple : Color.quizBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .configCard()
    }

    func diffLabel(_ d: Int) -> String {
        ["入门", "基础", "中等", "进阶", "挑战"][d - 1]
    }

    // MARK: - 题目数量
    var countSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("题目数量", icon: "doc.text.fill")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(totalCount) 题")
                        .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                    Text("可用题目：\(availableCount) 道")
                        .font(.system(size: 12))
                        .foregroundColor(availableCount < totalCount ? Color.quizRed : .secondary)
                }
                Spacer()
                HStack(spacing: 0) {
                    stepButton(icon: "minus", action: { if totalCount > 1 { totalCount -= 1 } })
                    Text("\(totalCount)")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 44)
                    stepButton(icon: "plus", action: { totalCount += 1 })
                }
                .background(Color.quizCard).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))
            }

            // 快捷数量
            HStack(spacing: 8) {
                ForEach([5, 10, 20, 30], id: \.self) { n in
                    Button { totalCount = n } label: {
                        Text("\(n)题")
                            .font(.system(size: 12))
                            .foregroundColor(totalCount == n ? .white : Color.quizPurpleLight)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(totalCount == n ? Color.quizPurple : Color.quizPurple.opacity(0.15))
                            .cornerRadius(14)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if availableCount < totalCount && availableCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundColor(.yellow)
                    Text("题目不足，实际将出 \(availableCount) 题")
                        .font(.system(size: 12)).foregroundColor(.yellow)
                }
            }
        }
        .configCard()
    }

    // MARK: - 分值设置
    var scoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("分值设置", icon: "rosette")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总分 \(totalScore) 分")
                        .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                    Text(scorePerQ).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 0) {
                    stepButton(icon: "minus", action: { if totalScore >= 15 { totalScore -= 5 } })
                    Text("\(totalScore)")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 44)
                    stepButton(icon: "plus", action: { totalScore += 5 })
                }
                .background(Color.quizCard).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))
            }

            // 快捷总分
            HStack(spacing: 8) {
                ForEach([60, 100, 120, 150], id: \.self) { s in
                    Button { totalScore = s } label: {
                        Text("\(s)分")
                            .font(.system(size: 12))
                            .foregroundColor(totalScore == s ? .white : Color.quizPurpleLight)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(totalScore == s ? Color.quizPurple : Color.quizPurple.opacity(0.15))
                            .cornerRadius(14)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // 分值模式
            VStack(alignment: .leading, spacing: 8) {
                Text("分值分配方式").font(.system(size: 13)).foregroundColor(.secondary)
                HStack(spacing: 10) {
                    ForEach(ExamConfig.ScoreMode.allCases) { mode in
                        Button { scoreMode = mode } label: {
                            HStack(spacing: 6) {
                                Image(systemName: scoreMode == mode ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(scoreMode == mode ? Color.quizPurpleLight : .secondary)
                                    .font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.rawValue)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(mode == .uniform ? "每题分值相同" : "难题分值更高")
                                        .font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(scoreMode == mode ? Color.quizPurple.opacity(0.2) : Color.quizBg)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(scoreMode == mode ? Color.quizPurple : Color.quizBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .configCard()
    }

    // MARK: - 答题模式
    var examModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("答题模式", icon: "lock.shield.fill")
            HStack(spacing: 10) {
                ForEach(ExamConfig.ExamMode.allCases) { mode in
                    let selected = examMode == mode
                    Button { examMode = mode } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(selected ? .white : Color.quizPurpleLight)
                                Text(mode.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selected ? .white : .white)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                            }
                            Text(mode.description)
                                .font(.system(size: 11))
                                .foregroundColor(selected ? .white.opacity(0.8) : .secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected ? Color.quizPurple : Color.quizBg)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? Color.quizPurple : Color.quizBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .configCard()
    }

    // MARK: - 汇总预览卡
    var summaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(value: "\(actualCount)", label: "题目数",  color: Color.quizPurpleLight)
            Divider().background(Color.quizBorder).frame(height: 36)
            summaryItem(value: "\(totalScore)",  label: "总分",    color: Color(red: 0.86, green: 0.55, blue: 0.25))
            Divider().background(Color.quizBorder).frame(height: 36)
            summaryItem(value: "\(selectedSubjects.count)", label: "科目数", color: Color.quizGreen)
            Divider().background(Color.quizBorder).frame(height: 36)
            summaryItem(value: "\(selectedDifficulties.count)", label: "难度档", color: Color(red: 0.88, green: 0.35, blue: 0.55))
        }
        .padding(.vertical, 14)
        .background(Color.quizCard).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.quizBorder, lineWidth: 0.5))
    }

    func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 操作按钮组
    var startButton: some View {
        VStack(spacing: 10) {
            // 生成并开始答题
            Button {
                let qs = config.selectQuestions(from: store.allQuestions)
                guard !qs.isEmpty else { return }
                generatedQuestions = qs
                generatedScores    = config.scores(for: qs)
                navigateToExam     = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 16))
                    Text("生成并开始答题").font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(canGenerate ? Color.quizPurple : Color.quizCard).cornerRadius(14)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canGenerate)

            // 导出空白试卷（线下打印）
            Button {
                guard canGenerate else { return }
                isGenBlankPDF = true
                let qs = config.selectQuestions(from: store.allQuestions)
                let scores = config.scores(for: qs)
                DispatchQueue.global(qos: .userInitiated).async {
                    let url = BlankExamPDFGenerator.generate(
                        config: config, questions: qs, questionScores: scores
                    )
                    DispatchQueue.main.async {
                        isGenBlankPDF = false
                        blankPDFURL   = url
                        showBlankPDF  = true
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isGenBlankPDF {
                        ProgressView().tint(Color.quizPurpleLight).scaleEffect(0.8)
                    } else {
                        Image(systemName: "printer.fill").font(.system(size: 15))
                    }
                    Text(isGenBlankPDF ? "生成中…" : "导出空白试卷（供打印）")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(canGenerate ? Color.quizPurpleLight : .secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.quizPurple.opacity(0.15)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.quizPurple.opacity(canGenerate ? 0.5 : 0.2), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canGenerate || isGenBlankPDF)

            if !canGenerate {
                Text(selectedSubjects.isEmpty ? "请先选择科目" : "所选条件下无可用题目")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 辅助组件
    func sectionHeader(_ title: String, icon: String, trailing: (() -> some View)? = nil) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Color.quizPurpleLight)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Spacer()
            trailing?()
        }
    }

    // Swift doesn't allow conditional trailing closures easily, so separate overload:
    func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Color.quizPurpleLight)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Spacer()
        }
    }

    func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.quizPurpleLight)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ViewModifier：配置卡片样式
private extension View {
    func configCard() -> some View {
        self.padding(16)
            .background(Color.quizCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.quizBorder, lineWidth: 0.5))
    }
}

#Preview {
    NavigationStack { ExamConfigView() }
        .environmentObject(QuizStore())
        .preferredColorScheme(.dark)
}
