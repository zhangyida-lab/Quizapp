//
//  QuizCategory.swift
//  swiftUI Practice
//
//  Created by tony on 4/6/26.
//


import SwiftUI

// MARK: - 题目分类

enum QuizCategory: String, CaseIterable, Identifiable {
    case geography = "地理"
    case science   = "科学"
    case history   = "历史"
    case math      = "数学"
    case art       = "艺术"
    case sports    = "体育"
    case random    = "随机"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .geography: return "globe.asia.australia.fill"
        case .science:   return "atom"
        case .history:   return "scroll.fill"
        case .math:      return "function"
        case .art:       return "paintpalette.fill"
        case .sports:    return "figure.run"
        case .random:    return "shuffle"
        }
    }

    var color: Color {
        switch self {
        case .geography: return Color(red: 0.20, green: 0.60, blue: 0.86)
        case .science:   return Color(red: 0.33, green: 0.78, blue: 0.62)
        case .history:   return Color(red: 0.86, green: 0.55, blue: 0.25)
        case .math:      return Color(red: 0.53, green: 0.40, blue: 0.88)
        case .art:       return Color(red: 0.88, green: 0.35, blue: 0.55)
        case .sports:    return Color(red: 0.25, green: 0.72, blue: 0.45)
        case .random:    return Color(red: 0.65, green: 0.65, blue: 0.72)
        }
    }

    var description: String {
        switch self {
        case .geography: return "探索世界地理知识"
        case .science:   return "挑战自然科学题目"
        case .history:   return "回顾历史长河"
        case .math:      return "数字与逻辑的世界"
        case .art:       return "感受艺术之美"
        case .sports:    return "体育竞技大考验"
        case .random:    return "随机混合 10 题"
        }
    }

    var questionCount: Int {
        if self == .random { return 10 }
        return allQuestions.filter { $0.category == rawValue }.count
    }
}

// MARK: - 主页视图

struct HomeView: View {
    @State private var selectedCategory: QuizCategory? = nil
    @State private var showDetail = false

    // 两列网格
    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // 顶部欢迎区
                    headerSection

                    // 今日推荐
                    featuredSection

                    // 分类网格
                    VStack(alignment: .leading, spacing: 14) {
                        Text("全部分类")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(QuizCategory.allCases) { category in
                                NavigationLink(destination: CategoryDetailView(category: category)) {
                                    CategoryCard(category: category)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
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

    // MARK: 顶部欢迎横幅
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("你好，答题达人 👋")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("今天挑战哪个分类？")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            // 全局统计小胶囊
            HStack(spacing: 12) {
                StatPill(icon: "list.bullet", value: "\(allQuestions.count)", label: "题目总数")
                StatPill(icon: "square.grid.2x2.fill", value: "\(QuizCategory.allCases.count - 1)", label: "分类数量")
                StatPill(icon: "shuffle", value: "10", label: "随机题数")
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
    }

    // MARK: 今日推荐横幅
    var featuredSection: some View {
        NavigationLink(destination: CategoryDetailView(category: .random)) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.quizPurple, Color(red: 0.20, green: 0.60, blue: 0.86)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 130)

                // 装饰圆圈
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 120, height: 120)
                    .offset(x: 240, y: -20)
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 80, height: 80)
                    .offset(x: 290, y: 30)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                            Text("今日推荐")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Text("随机混合挑战")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("10 道题 · 全类型混合")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    }
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 24)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }
}

// MARK: - 统计胶囊

struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(Color.quizPurpleLight)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.quizCard)
        .cornerRadius(20)
    }
}

// MARK: - 分类卡片

struct CategoryCard: View {
    let category: QuizCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图标区
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
                if category == .random {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 12)

            Text(category.rawValue)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Text(category.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.top, 2)

            Spacer(minLength: 10)

            // 题目数量
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
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.quizBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - 分类详情 / 开始答题页

struct CategoryDetailView: View {
    let category: QuizCategory
    @Environment(\.dismiss) private var dismiss

    var categoryQuestions: [Question] {
        questions(for: category)
    }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // 大图标横幅
                    bannerSection

                    // 本分类题目预览列表
                    if category != .random {
                        questionPreviewSection
                    } else {
                        randomHintSection
                    }

                    Spacer(minLength: 80)
                }
                .padding(.bottom, 20)
            }

            // 底部开始按钮
            VStack {
                Spacer()
                NavigationLink(destination: QuizContainerView(category: category)) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15))
                        Text("开始答题（\(category.questionCount) 题）")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(category.color)
                    .cornerRadius(14)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .background(
                    Color.quizBg
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: 横幅
    var bannerSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(category.color.opacity(0.12))
                .frame(height: 180)

            // 装饰
            Circle()
                .fill(category.color.opacity(0.08))
                .frame(width: 200, height: 200)
                .offset(x: 120, y: -40)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: 72, height: 72)
                    Image(systemName: category.icon)
                        .font(.system(size: 32))
                        .foregroundColor(category.color)
                }

                VStack(spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text(category.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: 题目预览
    var questionPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("题目预览")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("共 \(categoryQuestions.count) 题")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(Array(categoryQuestions.enumerated()), id: \.offset) { index, q in
                    HStack(spacing: 12) {
                        // 序号
                        ZStack {
                            Circle()
                                .fill(category.color.opacity(0.15))
                                .frame(width: 30, height: 30)
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(category.color)
                        }

                        Text(q.text)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)

                        Spacer()

                        if q.image != nil {
                            Image(systemName: "photo")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.quizCard)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.quizBorder, lineWidth: 0.5)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: 随机提示
    var randomHintSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "shuffle.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(Color.quizPurpleLight.opacity(0.6))

            VStack(spacing: 6) {
                Text("随机混合模式")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text("从全部 \(allQuestions.count) 道题中随机抽取 10 题")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("每次开始都是全新体验！")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // 涵盖分类标签
            FlowLayout(spacing: 8) {
                ForEach(QuizCategory.allCases.filter { $0 != .random }) { cat in
                    HStack(spacing: 4) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 11))
                        Text(cat.rawValue)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(cat.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(cat.color.opacity(0.12))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }
}

// MARK: - 简易流式布局（用于标签云）

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
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
    .preferredColorScheme(.dark)
}