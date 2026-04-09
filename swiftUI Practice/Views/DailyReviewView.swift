import SwiftUI

// MARK: - 今日推荐视图

struct DailyReviewView: View {
    @EnvironmentObject private var store: QuizStore
    @State private var showQuiz = false

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    statsRow
                    dueSectionIfNeeded
                    questionListSection
                    Spacer(minLength: 80)
                }
                .padding(.top, 16).padding(.bottom, 40)
            }

            // 底部开始按钮
            if !store.dailyQuestions.isEmpty {
                VStack {
                    Spacer()
                    NavigationLink(destination: QuizContainerView(
                        categoryName: "今日推荐",
                        categoryColor: Color.quizPurple,
                        questions: store.dailyQuestions
                    )) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill").font(.system(size: 15))
                            Text("开始今日练习（\(store.dailyQuestions.count) 题）")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.quizPurple).cornerRadius(14)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20).padding(.bottom, 32)
                    .background(Color.quizBg.ignoresSafeArea(edges: .bottom))
                }
            }
        }
        .navigationTitle("今日推荐")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.generateDailyRecommendations()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Color.quizPurpleLight)
                }
            }
        }
        .onAppear { store.refreshDailyIfNeeded() }
    }

    // MARK: 头部
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateString)
                .font(.system(size: 13)).foregroundColor(.secondary)
            Text(store.dailyQuestions.isEmpty ? "暂无推荐题目" : "今日为你精选了 \(store.dailyQuestions.count) 道题")
                .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
            if store.dueQuestions.count > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Color.quizRed).font(.system(size: 13))
                    Text("包含 \(min(store.dueQuestions.count, 15)) 道待复习错题")
                        .font(.system(size: 13)).foregroundColor(Color.quizRed.opacity(0.9))
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
    }

    var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }

    // MARK: 统计行
    var statsRow: some View {
        HStack(spacing: 12) {
            DailyStatCard(icon: "doc.text.fill",        value: "\(store.dailyQuestions.count)", label: "今日题数",   color: Color.quizPurpleLight)
            DailyStatCard(icon: "xmark.circle.fill",    value: "\(store.dueQuestions.count)",   label: "待复习",     color: Color.quizRed)
            DailyStatCard(icon: "checkmark.seal.fill",  value: "\(store.masteredCount)",         label: "已掌握",     color: Color.quizGreen)
        }
        .padding(.horizontal, 20)
    }

    // MARK: 到期错题提示
    @ViewBuilder
    var dueSectionIfNeeded: some View {
        if !store.dueQuestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("到期复习（\(min(store.dueQuestions.count, 15)) 题）")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.dueQuestions.prefix(15)) { q in
                            DueQuestionChip(question: q)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: 今日题目列表
    var questionListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日题目")
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 20)

            if store.dailyQuestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("暂无题目\n请先在题库中导入题目").font(.system(size: 14))
                        .foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(store.dailyQuestions.enumerated()), id: \.offset) { idx, q in
                        DailyQuestionRow(question: q, index: idx, record: store.wrongRecord(for: q.id))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - 子组件

struct DailyStatCard: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.quizCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizBorder, lineWidth: 0.5))
    }
}

struct DueQuestionChip: View {
    let question: Question
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question.category)
                .font(.system(size: 10)).foregroundColor(Color.quizRed)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.quizRed.opacity(0.15)).cornerRadius(4)
            Text(question.text).font(.system(size: 12)).foregroundColor(.white).lineLimit(2)
                .frame(width: 140, alignment: .leading)
        }
        .padding(10)
        .background(Color.quizCard).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizRed.opacity(0.4), lineWidth: 1))
        .frame(width: 160)
    }
}

struct DailyQuestionRow: View {
    let question: Question
    let index: Int
    let record: WrongRecord?

    var body: some View {
        HStack(spacing: 12) {
            // 序号
            ZStack {
                Circle().fill(indexColor.opacity(0.15)).frame(width: 32, height: 32)
                Text("\(index + 1)").font(.system(size: 13, weight: .medium)).foregroundColor(indexColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(question.text).font(.system(size: 14)).foregroundColor(.white).lineLimit(1)
                HStack(spacing: 8) {
                    Text(question.category).font(.system(size: 11)).foregroundColor(.secondary)
                    if let rec = record {
                        Text("错 \(rec.wrongCount) 次")
                            .font(.system(size: 10)).foregroundColor(Color.quizRed.opacity(0.8))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.quizRed.opacity(0.12)).cornerRadius(4)
                    }
                }
            }

            Spacer()
            Image(systemName: question.image != nil ? "photo" : "text.alignleft")
                .font(.system(size: 12)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.quizCard).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))
    }

    var indexColor: Color {
        guard let rec = record else { return Color.quizPurpleLight }
        return rec.isDue ? Color.quizRed : Color.quizPurpleLight
    }
}

#Preview {
    NavigationStack { DailyReviewView() }
        .environmentObject(QuizStore(modelContext: try! ModelContainer(for:
  QuestionBankEntity.self, WrongRecordEntity.self, ExamPaperEntity.self,
  AppSettingsEntity.self).mainContext))
        .preferredColorScheme(.dark)
}
