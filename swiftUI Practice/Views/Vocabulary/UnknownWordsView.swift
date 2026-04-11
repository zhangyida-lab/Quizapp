import SwiftUI

// MARK: - 不认识单词本
struct UnknownWordsView: View {
    @EnvironmentObject private var vocabStore: VocabularyStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWord: Word? = nil
    @State private var showFlashCard = false
    @State private var flashCardWords: [Word] = []   // 进入闪卡时的快照，避免 store 更新后数组变短导致越界
    @State private var searchText = ""

    private var words: [Word] { vocabStore.unknownWords }

    private var filtered: [Word] {
        guard !searchText.isEmpty else { return words }
        return words.filter {
            $0.word.localizedCaseInsensitiveContains(searchText) ||
            $0.primaryMeaning.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            if words.isEmpty {
                emptyState
            } else {
                wordList
            }

            // 底部练习按钮
            if !words.isEmpty {
                VStack {
                    Spacer()
                    Button {
                        flashCardWords = words.shuffled()
                        showFlashCard = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                                .font(.system(size: 15))
                            Text("闪卡练习（\(words.count) 词）")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.quizRed)
                        .cornerRadius(14)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .background(Color.quizBg.ignoresSafeArea(edges: .bottom))
                }
            }
        }
        .navigationTitle("不认识单词本")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !words.isEmpty {
                    Text("\(words.count) 词")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索单词或释义")
        .sheet(item: $selectedWord) { word in
            WordDetailSheet(word: word)
                .environmentObject(vocabStore)
        }
        .navigationDestination(isPresented: $showFlashCard) {
            FlashCardView(words: flashCardWords)
        }
    }

    // MARK: 单词列表
    private var wordList: some View {
        List {
            ForEach(filtered) { word in
                UnknownWordRow(
                    word: word,
                    record: vocabStore.wordRecord(for: word.id)
                ) {
                    selectedWord = word
                } onMarkMastered: {
                    vocabStore.toggleMastered(word.id)
                }
                .listRowBackground(Color.quizCard)
                .listRowSeparatorTint(Color.quizBorder)
            }

            // 底部留白，防止被按钮遮住最后一行
            Color.clear.frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: 空状态
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.quizGreen)
            Text("太棒了！")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            Text("没有不认识的单词\n继续坚持练习，保持这个状态！")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - 不认识单词行
private struct UnknownWordRow: View {
    let word: Word
    let record: WordRecord?
    let onTap: () -> Void
    let onMarkMastered: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 错误次数标记
            ZStack {
                Circle()
                    .fill(Color.quizRed.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(record?.studyCount ?? 0)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.quizRed)
            }

            // 单词信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.word)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    if !word.phonetic.isEmpty {
                        Text(word.phonetic)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Text(word.primaryMeaning)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 标记已掌握按钮
            Button {
                onMarkMastered()
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.quizGreen.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

#Preview {
    NavigationStack {
        UnknownWordsView()
    }
    .environmentObject(VocabularyStore())
    .preferredColorScheme(.dark)
}
