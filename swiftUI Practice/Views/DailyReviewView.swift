import SwiftUI
import SwiftData

// MARK: - 今日推荐视图

struct DailyReviewView: View {
    @EnvironmentObject private var store: QuizStore
    @EnvironmentObject private var vocabStore: VocabularyStore

    @State private var mode: ReviewMode = .vocab
    @State private var flashCardWords: [Word] = []
    @State private var showFlashCard = false

    enum ReviewMode { case quiz, vocab }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    modePicker
                    if mode == .quiz {
                        quizContent
                    } else {
                        vocabContent
                    }
                    Spacer(minLength: 80)
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.2), value: mode)
            }

            // 底部按钮（随模式切换）
            bottomButton
        }
        .navigationTitle("推荐")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if mode == .quiz {
                        store.generateDailyRecommendations()
                    } else {
                        vocabStore.generateDailyWords()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Color.quizPurpleLight)
                }
            }
        }
        .onAppear {
            store.refreshDailyIfNeeded()
            vocabStore.refreshDailyIfNeeded()
        }
        .navigationDestination(isPresented: $showFlashCard) {
            FlashCardView(words: flashCardWords)
        }
    }

    // MARK: 模式切换胶囊
    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach([ReviewMode.quiz, ReviewMode.vocab], id: \.self) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = m }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m == .quiz ? "doc.text.fill" : "text.book.closed.fill")
                            .font(.system(size: 13))
                        Text(m == .quiz ? "刷题" : "背词")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(mode == m ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        mode == m
                            ? Color.quizPurple
                            : Color.clear
                    )
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color.quizCard)
        .cornerRadius(13)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.quizBorder, lineWidth: 0.5))
        .padding(.horizontal, 20)
    }

    // MARK: ── 题目面板 ──────────────────────────────

    private var quizContent: some View {
        VStack(spacing: 20) {
            quizStatsRow
            dueSectionIfNeeded
            questionListSection
        }
    }

    private var quizStatsRow: some View {
        HStack(spacing: 12) {
            DailyStatCard(icon: "doc.text.fill",
                          value: "\(store.dailyQuestions.count)",
                          label: "今日题数", color: Color.quizPurpleLight)
            DailyStatCard(icon: "xmark.circle.fill",
                          value: "\(store.dueQuestions.count)",
                          label: "待复习", color: Color.quizRed)
            DailyStatCard(icon: "checkmark.seal.fill",
                          value: "\(store.masteredCount)",
                          label: "已掌握", color: Color.quizGreen)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var dueSectionIfNeeded: some View {
        if !store.dueQuestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("到期复习（\(min(store.dueQuestions.count, 15)) 题）")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    NavigationLink(destination: QuizContainerView(
                        categoryName: "错题复习",
                        categoryColor: Color.quizRed,
                        questions: Array(store.dueQuestions.prefix(15))
                    )) {
                        Text("开始复习")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.quizRed)
                            .cornerRadius(14)
                    }
                }
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

    private var questionListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日题目")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            if store.dailyQuestions.isEmpty {
                emptyState(icon: "tray", message: "暂无题目\n请先在题库中导入题目")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(store.dailyQuestions.enumerated()), id: \.offset) { idx, q in
                        DailyQuestionRow(question: q, index: idx,
                                         record: store.wrongRecord(for: q.id))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: ── 词汇面板 ──────────────────────────────

    private var vocabContent: some View {
        VStack(spacing: 20) {
            vocabStatsRow
            dueWordsSection
            dailyWordListSection
        }
    }

    private var vocabStatsRow: some View {
        HStack(spacing: 12) {
            DailyStatCard(icon: "text.book.closed.fill",
                          value: "\(vocabStore.dailyWords.count)",
                          label: "今日单词", color: Color.quizPurpleLight)
            DailyStatCard(icon: "clock.arrow.circlepath",
                          value: "\(vocabStore.dueCount)",
                          label: "待复习", color: Color.quizRed)
            DailyStatCard(icon: "checkmark.seal.fill",
                          value: "\(vocabStore.masteredCount)",
                          label: "已掌握", color: Color.quizGreen)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var dueWordsSection: some View {
        if !vocabStore.dueWords.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("待复习单词（\(min(vocabStore.dueWords.count, 15)) 个）")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vocabStore.dueWords.prefix(15)) { w in
                            DueWordChip(word: w)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var dailyWordListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日单词")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            if vocabStore.dailyWords.isEmpty {
                emptyState(icon: "text.book.closed", message: "暂无单词\n请先在词汇 Tab 中启用词库")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(vocabStore.dailyWords.enumerated()), id: \.offset) { idx, w in
                        DailyWordRow(word: w, index: idx,
                                     record: vocabStore.wordRecord(for: w.id))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: ── 底部按钮 ──────────────────────────────

    @ViewBuilder
    private var bottomButton: some View {
        VStack {
            Spacer()
            if mode == .quiz, !store.dailyQuestions.isEmpty {
                NavigationLink(destination: QuizContainerView(
                    categoryName: "推荐",
                    categoryColor: Color.quizPurple,
                    questions: store.dailyQuestions
                )) {
                    startButtonLabel(
                        icon: "play.fill",
                        text: "开始（\(store.dailyQuestions.count) 题）",
                        color: Color.quizPurple
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20).padding(.bottom, 32)
                .background(Color.quizBg.ignoresSafeArea(edges: .bottom))

            } else if mode == .vocab, !vocabStore.dailyWords.isEmpty {
                Button {
                    flashCardWords = vocabStore.dailyWords.shuffled()
                    showFlashCard = true
                } label: {
                    startButtonLabel(
                        icon: "rectangle.on.rectangle.angled",
                        text: "开始词汇练习（\(vocabStore.dailyWords.count) 词）",
                        color: Color(red: 0.33, green: 0.62, blue: 0.93)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20).padding(.bottom, 32)
                .background(Color.quizBg.ignoresSafeArea(edges: .bottom))
            }
        }
    }

    private func startButtonLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15))
            Text(text).font(.system(size: 17, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color)
        .cornerRadius(14)
    }

    // MARK: 空状态
    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(.secondary)
            Text(message).font(.system(size: 14))
                .foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

// MARK: - 待复习单词胶囊

struct DueWordChip: View {
    let word: Word
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(word.partOfSpeech)
                .font(.system(size: 10)).foregroundColor(Color.quizRed)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.quizRed.opacity(0.15)).cornerRadius(4)
            Text(word.word)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            Text(word.primaryMeaning)
                .font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                .frame(width: 120, alignment: .leading)
        }
        .padding(10)
        .background(Color.quizCard).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizRed.opacity(0.4), lineWidth: 1))
        .frame(width: 140)
    }
}

// MARK: - 今日单词行

struct DailyWordRow: View {
    let word: Word
    let index: Int
    let record: WordRecord?

    var body: some View {
        HStack(spacing: 12) {
            // 序号
            ZStack {
                Circle().fill(indexColor.opacity(0.15)).frame(width: 32, height: 32)
                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(indexColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(word.word)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    if !word.phonetic.isEmpty {
                        Text(word.phonetic)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Text(word.primaryMeaning)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 掌握程度标签
            if let rec = record {
                Text(rec.masteryLevel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(masteryColor(rec))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(masteryColor(rec).opacity(0.15))
                    .cornerRadius(5)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Color.quizCard).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))
    }

    private var indexColor: Color {
        guard let rec = record else { return Color.quizPurpleLight }
        return rec.isDue ? Color.quizRed : Color.quizPurpleLight
    }

    private func masteryColor(_ rec: WordRecord) -> Color {
        switch rec.masteryColorName {
        case "green":  return .quizGreen
        case "blue":   return Color(red: 0.25, green: 0.55, blue: 0.95)
        case "yellow": return Color(red: 0.95, green: 0.75, blue: 0.20)
        default:       return .quizRed
        }
    }
}

// MARK: - 子组件（共用）

struct DailyStatCard: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.quizCard).cornerRadius(12)
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
            Text(question.text)
                .font(.system(size: 12)).foregroundColor(.white).lineLimit(2)
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
        .environmentObject(VocabularyStore())
        .preferredColorScheme(.dark)
}
