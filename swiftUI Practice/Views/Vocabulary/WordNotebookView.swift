import SwiftUI

// MARK: - 单词本（待复习列表）
struct WordNotebookView: View {
    @EnvironmentObject private var vocabStore: VocabularyStore

    @State private var filter: Filter = .due
    @State private var selectedWord: Word? = nil
    @State private var showFlashCard = false
    @State private var flashWords: [Word] = []

    enum Filter: String, CaseIterable {
        case due      = "待复习"
        case studying = "学习中"
        case mastered = "已掌握"
        case all      = "全部"
    }

    var displayedWords: [Word] {
        switch filter {
        case .due:
            return vocabStore.dueWords
        case .studying:
            let ids = Set(vocabStore.wordRecords.filter { !$0.isMastered && $0.studyCount > 0 }.map { $0.wordId })
            return vocabStore.allWords.filter { ids.contains($0.id) }
        case .mastered:
            return vocabStore.masteredWords
        case .all:
            return vocabStore.studiedWords
        }
    }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // 筛选器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Filter.allCases, id: \.self) { f in
                            FilterChip(title: f.rawValue, count: countFor(f), isSelected: filter == f) {
                                filter = f
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }

                if displayedWords.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(displayedWords) { word in
                            NotebookRow(
                                word: word,
                                record: vocabStore.wordRecord(for: word.id)
                            )
                            .listRowBackground(Color.quizCard)
                            .listRowSeparatorTint(Color.quizBorder)
                            .onTapGesture { selectedWord = word }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }

            // 底部复习按钮（仅待复习 tab 且有数据时）
            if filter == .due && !displayedWords.isEmpty {
                VStack {
                    Spacer()
                    Button {
                        flashWords = displayedWords.shuffled()
                        showFlashCard = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                            Text("开始复习 \(displayedWords.count) 个单词")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.quizPurple)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .navigationTitle("单词本")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $selectedWord) { word in
            WordDetailSheet(word: word)
                .environmentObject(vocabStore)
        }
        .navigationDestination(isPresented: $showFlashCard) {
            FlashCardView(words: flashWords)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.quizPurpleLight.opacity(0.5))
            Text(emptyMessage)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .due:      return "暂无待复习单词\n继续学习新单词吧"
        case .studying: return "还没有学习中的单词"
        case .mastered: return "还没有已掌握的单词"
        case .all:      return "还没有学习记录\n去首页开始学习吧"
        }
    }

    private func countFor(_ f: Filter) -> Int {
        switch f {
        case .due:      return vocabStore.dueCount
        case .studying:
            return vocabStore.wordRecords.filter { !$0.isMastered && $0.studyCount > 0 }.count
        case .mastered: return vocabStore.masteredCount
        case .all:      return vocabStore.studiedWords.count
        }
    }
}

// MARK: - 筛选标签
private struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? Color.quizPurple : .secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background((isSelected ? Color.white : Color.quizBorder).opacity(0.25))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(isSelected ? Color.quizPurple : Color.quizCard)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 列表行
private struct NotebookRow: View {
    let word: Word
    let record: WordRecord?

    var masteryColor: Color {
        guard let r = record else { return .secondary }
        switch r.masteryColorName {
        case "green":  return .quizGreen
        case "blue":   return Color(red: 0.25, green: 0.55, blue: 0.95)
        case "yellow": return Color(red: 0.95, green: 0.75, blue: 0.20)
        default:       return .quizRed
        }
    }

    var nextReviewText: String {
        guard let r = record, !r.isMastered else { return "" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: r.nextReviewDate).day ?? 0
        if days <= 0 { return "今日复习" }
        if days == 1 { return "明天复习" }
        return "\(days) 天后复习"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.word)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(word.phonetic)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Text(word.primaryMeaning)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let r = record {
                    Text(r.masteryLevel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(masteryColor)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(masteryColor.opacity(0.15))
                        .cornerRadius(6)
                }
                if !nextReviewText.isEmpty {
                    Text(nextReviewText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        WordNotebookView()
    }
    .environmentObject(VocabularyStore())
    .preferredColorScheme(.dark)
}
