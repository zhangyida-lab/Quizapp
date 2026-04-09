import SwiftUI

// MARK: - 主页视图

struct HomeView: View {
    @EnvironmentObject private var store: QuizStore

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
                Image(systemName: "bell.fill")
                    .foregroundColor(Color.quizPurpleLight)
                    .font(.system(size: 16))
            }
        }
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
