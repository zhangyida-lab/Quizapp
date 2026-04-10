import SwiftUI
import SwiftData 

// MARK: - 主页视图

struct HomeView: View {
    @EnvironmentObject private var store: QuizStore
    @State private var showHelp = false

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    featuredSection
                    categoryGridSection
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("趣味答题")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(Color.quizPurpleLight)
                        .font(.system(size: 18))
                }
            }
        }
        .sheet(isPresented: $showHelp) { HelpView() }
    }

    // MARK: 顶部欢迎区
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("你好，答题达人 👋")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("今天挑战哪个分类？")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                StatPill(icon: "list.bullet",       value: "\(store.allQuestions.count)", label: "题目总数")
                StatPill(icon: "square.grid.2x2",   value: "\(store.categories.count)",   label: "分类数量")
                StatPill(icon: "xmark.circle.fill",  value: "\(store.wrongTotalCount)",    label: "错题数")
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
    }

    // MARK: 今日推荐横幅
    var featuredSection: some View {
        NavigationLink(destination: randomQuizDestination) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        colors: [Color.quizPurple, Color(red: 0.20, green: 0.60, blue: 0.86)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(height: 130)

                Circle().fill(Color.white.opacity(0.07)).frame(width: 120, height: 120).offset(x: 240, y: -20)
                Circle().fill(Color.white.opacity(0.05)).frame(width: 80, height: 80).offset(x: 290, y: 30)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.yellow)
                            Text("今日推荐").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.85))
                        }
                        Text("随机混合挑战").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        Text("\(min(store.dailyQuestions.count, 20)) 道题 · 全类型混合")
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(Color.white.opacity(0.15)).frame(width: 52, height: 52)
                        Image(systemName: "play.fill").font(.system(size: 18)).foregroundColor(.white).offset(x: 2)
                    }
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 24)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    var randomQuizDestination: some View {
        let qs = store.allQuestions.shuffled().prefix(10)
        QuizContainerView(
            categoryName: "随机混合",
            categoryColor: Color.quizPurple,
            questions: Array(qs)
        )
    }

    // MARK: 分类网格
    var categoryGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("全部分类")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            if store.categories.isEmpty {
                Text("暂无题目，请前往题库导入")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.categories) { category in
                        NavigationLink(destination: CategoryDetailView(category: category)) {
                            CategoryCard(category: category)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - 统计胶囊

struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(Color.quizPurpleLight)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.quizCard)
        .cornerRadius(20)
    }
}

// MARK: - 分类卡片

struct CategoryCard: View {
    let category: CategoryInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(category.color.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(category.color)
                }
                Spacer()
            }
            .padding(.bottom, 12)

            Text(category.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Text(category.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.top, 2)

            Spacer(minLength: 10)

            HStack(spacing: 4) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 10))
                    .foregroundColor(category.color.opacity(0.8))
                Text("\(category.questionCount) 题")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(category.color.opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.12))
            .cornerRadius(6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Color.quizCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.quizBorder, lineWidth: 0.5))
    }
}

// MARK: - 分类详情页

struct CategoryDetailView: View {
    let category: CategoryInfo
    @EnvironmentObject private var store: QuizStore
    @State private var questions: [Question] = []

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    bannerSection
                    questionPreviewSection
                    Spacer(minLength: 80)
                }
                .padding(.bottom, 20)
            }

            // 底部开始按钮
            VStack {
                Spacer()
                NavigationLink(destination: QuizContainerView(
                    categoryName: category.name,
                    categoryColor: category.color,
                    questions: questions
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill").font(.system(size: 15))
                        Text("开始答题（\(questions.count) 题）")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(questions.isEmpty ? Color.quizCard : category.color)
                    .cornerRadius(14)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(questions.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .background(Color.quizBg.ignoresSafeArea(edges: .bottom))
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { questions = store.questions(for: category.name) }
    }

    var bannerSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(category.color.opacity(0.12))
                .frame(height: 160)
            Circle().fill(category.color.opacity(0.08)).frame(width: 200, height: 200).offset(x: 120, y: -40)

            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(category.color.opacity(0.2)).frame(width: 72, height: 72)
                    Image(systemName: category.icon).font(.system(size: 32)).foregroundColor(category.color)
                }
                VStack(spacing: 4) {
                    Text(category.name).font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                    Text(category.description).font(.system(size: 14)).foregroundColor(.secondary)
                }
            }
        }
    }

    var questionPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("题目预览").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Text("共 \(questions.count) 题").font(.system(size: 13)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, q in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(category.color.opacity(0.15)).frame(width: 30, height: 30)
                            Text("\(index + 1)").font(.system(size: 13, weight: .medium)).foregroundColor(category.color)
                        }
                        Text(q.text).font(.system(size: 14)).foregroundColor(.white.opacity(0.85)).lineLimit(1)
                        Spacer()
                        if q.image != nil {
                            Image(systemName: "photo").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.quizCard)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 流式布局（标签云）

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0, rowWidth: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width && rowWidth > 0 {
                height += rowHeight + spacing; rowWidth = 0; rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: height + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing; x = bounds.minX; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - 帮助文档

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.quizBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(helpSections) { section in
                            HelpSectionCard(section: section)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("使用帮助")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(Color.quizPurpleLight)
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: 帮助内容数据
    var helpSections: [HelpSection] {[
        HelpSection(
            icon: "house.fill",
            color: Color.quizPurple,
            title: "首页",
            items: [
                HelpItem(q: "如何开始答题？",
                         a: "在首页点击分类卡片进入该分类，点击底部「开始答题」按钮即可开始。也可以点击「今日推荐」横幅进行随机混合练习。"),
                HelpItem(q: "今日推荐是怎么生成的？",
                         a: "系统每天自动推荐最多 20 道题：优先挑选错题本中到期需要复习的题目（最多 15 道），剩余名额从其他题目随机补充。"),
                HelpItem(q: "分类卡片上的题数是什么意思？",
                         a: "显示该分类下所有已启用题库中的题目总数。"),
            ]
        ),
        HelpSection(
            icon: "tray.full.fill",
            color: Color(red: 0.86, green: 0.55, blue: 0.25),
            title: "题库管理",
            items: [
                HelpItem(q: "如何导入题库？",
                         a: "进入「题库管理」，点击「导入 JSON」选择本地 JSON 文件；或点击「扫码导入」扫描分享二维码直接导入。"),
                HelpItem(q: "JSON 文件格式是什么？",
                         a: "JSON 需包含 version、name、questions 字段。每道题需填写 category（分类）、text（题目）、options（选项数组）、correctIndex（正确选项序号，从 0 起）。difficulty（1-5）和 explanation（解析）为可选字段。"),
                HelpItem(q: "如何分享题库？",
                         a: "在题库卡片上点击「二维码」，系统会将题库上传并生成分享码，他人扫码即可导入。点击「导出」可将题库保存为 JSON 文件分享。"),
                HelpItem(q: "如何管理分类？",
                         a: "在「分类管理」区域，每行右侧的开关可隐藏/显示该分类（隐藏后首页不再显示，也不计入今日推荐）。点击铅笔图标可重命名分类，修改后该分类下所有题目同步更新。"),
            ]
        ),
        HelpSection(
            icon: "doc.text.magnifyingglass",
            color: Color(red: 0.20, green: 0.60, blue: 0.86),
            title: "生成试卷",
            items: [
                HelpItem(q: "如何生成一份试卷？",
                         a: "进入「题库管理」→「生成试卷」，选择科目、难度范围、题数、总分及计分方式，点击「开始考试」即可。"),
                HelpItem(q: "练习模式和考试模式有什么区别？",
                         a: "练习模式每题作答后立即显示对错和解析；考试模式所有题作答完毕点击「交卷」后才显示结果，模拟真实考试环境。"),
                HelpItem(q: "如何查看历史试卷？",
                         a: "进入「题库管理」→「历史试卷」，可查看所有已保存试卷的历次作答记录，也可点击「重新作答」再次练习同一套题。"),
            ]
        ),
        HelpSection(
            icon: "xmark.circle.fill",
            color: Color.quizRed,
            title: "错题本",
            items: [
                HelpItem(q: "错题是如何收录的？",
                         a: "答题过程中每道答错的题目会自动记录到错题本，系统使用 SM-2 间隔重复算法计算下次复习时间。"),
                HelpItem(q: "什么是「到期复习」？",
                         a: "根据答题情况，系统会预测遗忘曲线，在最佳复习时机将题目标记为「到期」，优先出现在今日推荐中。"),
                HelpItem(q: "如何标记已掌握？",
                         a: "在错题本中长按某道题，选择「标记已掌握」，该题不再出现在待复习列表中。也可随时取消掌握标记。"),
            ]
        ),
        HelpSection(
            icon: "doc.richtext.fill",
            color: Color.quizGreen,
            title: "PDF 导出",
            items: [
                HelpItem(q: "答题结束后如何导出成绩报告？",
                         a: "答题结束后，在结果页点击「导出 PDF」，系统自动生成包含题目详情和答题情况的成绩报告，可分享或保存到文件。"),
                HelpItem(q: "考试成绩单和空白试卷有什么不同？",
                         a: "「导出成绩单 PDF」包含你的作答情况和对错标注；「空白试卷」仅包含题目和选项，适合打印后线下作答。"),
            ]
        ),
    ]}
}

// MARK: - 帮助数据模型

struct HelpSection: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let items: [HelpItem]
}

struct HelpItem: Identifiable {
    let id = UUID()
    let q: String   // 问题
    let a: String   // 答案
}

// MARK: - 帮助章节卡片

struct HelpSectionCard: View {
    let section: HelpSection
    @State private var expandedItem: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 章节标题
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(section.color.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: section.icon)
                        .font(.system(size: 14))
                        .foregroundColor(section.color)
                }
                Text(section.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().background(Color.quizBorder)

            // 问答列表
            VStack(spacing: 0) {
                ForEach(section.items) { item in
                    HelpItemRow(item: item,
                                isExpanded: expandedItem == item.id,
                                accentColor: section.color) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedItem = expandedItem == item.id ? nil : item.id
                        }
                    }
                    if item.id != section.items.last?.id {
                        Divider().background(Color.quizBorder).padding(.leading, 14)
                    }
                }
            }
        }
        .background(Color.quizCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.quizBorder, lineWidth: 0.5))
    }
}

// MARK: - 单条问答行（可展开）

struct HelpItemRow: View {
    let item: HelpItem
    let isExpanded: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(accentColor.opacity(0.8))
                    Text(item.q)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if isExpanded {
                    Text(item.a)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject(QuizStore(modelContext: try! ModelContainer(for:
  QuestionBankEntity.self, WrongRecordEntity.self, ExamPaperEntity.self,
  AppSettingsEntity.self).mainContext))
    .preferredColorScheme(.dark)
}
