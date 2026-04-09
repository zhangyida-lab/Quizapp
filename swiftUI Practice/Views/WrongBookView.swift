import SwiftUI

// MARK: - 错题本

struct WrongBookView: View {
    @EnvironmentObject private var store: QuizStore
    @State private var filterMode: FilterMode = .all
    @State private var showClearConfirm = false

    enum FilterMode: String, CaseIterable {
        case all      = "全部"
        case due      = "待复习"
        case mastered = "已掌握"
    }

    var filteredQuestions: [Question] {
        switch filterMode {
        case .all:      return store.wrongQuestions
        case .due:      return store.dueQuestions
        case .mastered:
            let ids = Set(store.wrongRecords.filter { $0.isMastered }.map { $0.questionId })
            return store.allQuestions.filter { ids.contains($0.id) }
        }
    }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            VStack(spacing: 0) {
                statsHeader
                filterBar
                    .padding(.top, 12)

                if filteredQuestions.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredQuestions) { q in
                                WrongQuestionCard(question: q, record: store.wrongRecord(for: q.id))
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12).padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle("错题本")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) { showClearConfirm = true } label: {
                        Label("清空错题记录", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundColor(Color.quizPurpleLight)
                }
            }
        }
        .confirmationDialog("确定清空所有错题记录？此操作不可撤销。",
                            isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) { store.clearAllWrongRecords() }
        }
    }

    // MARK: 顶部统计
    var statsHeader: some View {
        HStack(spacing: 12) {
            WrongStatPill(value: "\(store.wrongRecords.count)", label: "总错题", color: Color.quizRed)
            WrongStatPill(value: "\(store.dueQuestions.count)", label: "待复习", color: Color(red: 0.86, green: 0.55, blue: 0.25))
            WrongStatPill(value: "\(store.masteredCount)",      label: "已掌握", color: Color.quizGreen)
        }
        .padding(.horizontal, 16).padding(.top, 12)
    }

    // MARK: 筛选栏
    var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(FilterMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { filterMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: filterMode == mode ? .semibold : .regular))
                        .foregroundColor(filterMode == mode ? .white : .secondary)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(filterMode == mode ? Color.quizPurple : Color.quizCard)
                        .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
            if filterMode == .due && !store.dueQuestions.isEmpty {
                NavigationLink(destination: QuizContainerView(
                    categoryName: "错题复习",
                    categoryColor: Color.quizRed,
                    questions: store.dueQuestions
                )) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill").font(.system(size: 11))
                        Text("开始复习").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.quizRed).cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: 空状态
    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: filterMode == .mastered ? "checkmark.seal.fill" : "bookmark.slash")
                .font(.system(size: 52)).foregroundColor(.secondary.opacity(0.5))
            Text(emptyTitle).font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
            Text(emptySubtitle).font(.system(size: 14)).foregroundColor(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    var emptyTitle: String {
        switch filterMode {
        case .all: return "还没有错题"
        case .due: return "没有待复习的题目"
        case .mastered: return "还没有掌握的题目"
        }
    }

    var emptySubtitle: String {
        switch filterMode {
        case .all: return "去答题吧，答错的题目会自动收录到这里"
        case .due: return "太棒了！所有错题都复习到位了"
        case .mastered: return "答对三次以上的题目将标记为掌握"
        }
    }
}

// MARK: - 错题卡片

struct WrongQuestionCard: View {
    let question: Question
    let record: WrongRecord?
    @EnvironmentObject private var store: QuizStore
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部行
            HStack(spacing: 8) {
                Text(question.category)
                    .font(.system(size: 11)).foregroundColor(categoryColor)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(categoryColor.opacity(0.15)).cornerRadius(4)

                Spacer()

                if let rec = record {
                    masteryBadge(rec)
                    Text("错 \(rec.wrongCount) 次")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }

                // 标记掌握按钮
                Button {
                    withAnimation { store.toggleMastered(question.id) }
                } label: {
                    Image(systemName: record?.isMastered == true ? "checkmark.seal.fill" : "checkmark.seal")
                        .font(.system(size: 16))
                        .foregroundColor(record?.isMastered == true ? Color.quizGreen : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // 题目文字
            Text(question.text).font(.system(size: 15)).foregroundColor(.white).lineLimit(2)

            // 底部信息行
            HStack(spacing: 12) {
                if let rec = record {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 10))
                        Text(nextReviewText(rec)).font(.system(size: 11))
                    }
                    .foregroundColor(rec.isDue ? Color.quizRed : .secondary)
                }
                Spacer()
                // 查看详情
                Button {
                    showDetail = true
                } label: {
                    Text("查看").font(.system(size: 12)).foregroundColor(Color.quizPurpleLight)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(14)
        .background(Color.quizCard).cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(record?.isDue == true ? Color.quizRed.opacity(0.4) : Color.quizBorder, lineWidth: 0.8)
        )
        .sheet(isPresented: $showDetail) {
            WrongQuestionDetailView(question: question, record: record)
        }
    }

    var categoryColor: Color {
        CategoryInfo(id: question.category, name: question.category, questionCount: 0).color
    }

    @ViewBuilder
    func masteryBadge(_ rec: WrongRecord) -> some View {
        let (label, color) = masteryInfo(rec)
        Text(label).font(.system(size: 10)).foregroundColor(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.15)).cornerRadius(4)
    }

    func masteryInfo(_ rec: WrongRecord) -> (String, Color) {
        if rec.isMastered   { return ("已掌握", Color.quizGreen) }
        if rec.correctStreak >= 3 { return ("较熟练", Color(red: 0.20, green: 0.60, blue: 0.86)) }
        if rec.correctStreak >= 1 { return ("进步中", Color(red: 0.86, green: 0.55, blue: 0.25)) }
        return ("待巩固", Color.quizRed)
    }

    func nextReviewText(_ rec: WrongRecord) -> String {
        if rec.isMastered { return "已掌握" }
        if rec.isDue { return "今日复习" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: rec.nextReviewDate).day ?? 0
        return "\(days) 天后复习"
    }
}

// MARK: - 错题详情

struct WrongQuestionDetailView: View {
    let question: Question
    let record: WrongRecord?
    @EnvironmentObject private var store: QuizStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.quizBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // 统计卡片
                        if let rec = record {
                            statsCard(rec)
                        }

                        // 题目内容
                        QuestionCard(question: question)

                        // 选项（显示正确答案）
                        VStack(spacing: 10) {
                            ForEach(0..<question.options.count, id: \.self) { i in
                                OptionButton(
                                    label: ["A","B","C","D"][i],
                                    text: question.options[i],
                                    state: i == question.correctIndex ? .correct : .dimmed,
                                    isAnswered: true,
                                    action: {}
                                )
                            }
                        }

                        // AI 解析预留
                        aiExplanationPlaceholder
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .navigationTitle("错题详情").navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }.foregroundColor(Color.quizPurpleLight)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { store.toggleMastered(question.id) }
                    } label: {
                        Image(systemName: record?.isMastered == true ? "checkmark.seal.fill" : "checkmark.seal")
                            .foregroundColor(record?.isMastered == true ? Color.quizGreen : Color.quizPurpleLight)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    func statsCard(_ rec: WrongRecord) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(rec.wrongCount)", label: "答错次数", color: Color.quizRed)
            Divider().background(Color.quizBorder).frame(height: 40)
            statItem(value: "\(rec.correctStreak)", label: "连续答对", color: Color.quizGreen)
            Divider().background(Color.quizBorder).frame(height: 40)
            statItem(value: "\(rec.intervalDays)天", label: "复习间隔", color: Color.quizPurpleLight)
        }
        .padding(.vertical, 14).background(Color.quizCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizBorder, lineWidth: 0.5))
    }

    func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    var aiExplanationPlaceholder: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundColor(.secondary)
                Text("AI 解析").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Text("即将推出").font(.system(size: 11)).foregroundColor(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.quizBorder.opacity(0.5)).cornerRadius(4)
            }
            if let explanation = question.explanation {
                Text(explanation).font(.system(size: 14)).foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("暂无解析内容").font(.system(size: 13)).foregroundColor(.secondary)
            }
        }
        .padding(14).background(Color.quizCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizBorder, lineWidth: 0.5))
    }
}

// MARK: - 辅助组件

struct WrongStatPill: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.quizCard).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

#Preview {
    NavigationStack { WrongBookView() }
        .environmentObject(QuizStore(modelContext: try! ModelContainer(for:
  QuestionBankEntity.self, WrongRecordEntity.self, ExamPaperEntity.self,
  AppSettingsEntity.self).mainContext))
        .preferredColorScheme(.dark)
}
