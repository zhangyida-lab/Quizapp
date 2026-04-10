import SwiftUI

// MARK: - 词汇学习主页
struct VocabularyHomeView: View {
    @EnvironmentObject private var vocabStore: VocabularyStore

    @State private var showFlashCard = false
    @State private var showChoice    = false
    @State private var flashWords: [Word] = []
    @State private var choiceWords: [Word] = []
    @State private var selectedBook: WordBook? = nil

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    statsHeader
                    dailyBanner
                    studyModesSection
                    wordBooksSection
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("词汇学习")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // 闪卡
        .navigationDestination(isPresented: $showFlashCard) {
            FlashCardView(words: flashWords)
        }
        // 选词练习
        .navigationDestination(isPresented: $showChoice) {
            WordChoiceView(words: choiceWords, allWords: vocabStore.allWords)
        }
        // 词库详情
        .navigationDestination(item: $selectedBook) { book in
            WordBookDetailView(book: book)
        }
    }

    // MARK: 统计栏
    private var statsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("你好，学习达人 👋")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("今天记几个单词？")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                StatPill(icon: "text.book.closed.fill",
                         value: "\(vocabStore.allWords.count)", label: "单词总数")
                StatPill(icon: "checkmark.seal.fill",
                         value: "\(vocabStore.masteredCount)", label: "已掌握")
                StatPill(icon: "clock.arrow.circlepath",
                         value: "\(vocabStore.dueCount)", label: "待复习")
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
    }

    // MARK: 今日复习横幅
    private var dailyBanner: some View {
        Button {
            let words = vocabStore.dailyWords.isEmpty ? Array(vocabStore.allWords.shuffled().prefix(20)) : vocabStore.dailyWords
            flashWords = words
            showFlashCard = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.quizPurple.opacity(0.25))
                        .frame(width: 52, height: 52)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24))
                        .foregroundColor(Color.quizPurpleLight)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日复习")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    let count = vocabStore.dailyWords.count
                    Text(count > 0 ? "今天有 \(count) 个单词待学习" : "所有单词已完成今日复习 🎉")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.quizPurpleLight)
            }
            .padding(16)
            .background(Color.quizCard)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.quizPurple.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }

    // MARK: 学习模式
    private var studyModesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("学习模式")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            HStack(spacing: 14) {
                StudyModeCard(
                    icon: "rectangle.on.rectangle.angled",
                    title: "闪卡记忆",
                    subtitle: "翻卡记单词",
                    color: Color(red: 0.33, green: 0.62, blue: 0.93)
                ) {
                    let words = Array(vocabStore.allWords.shuffled().prefix(20))
                    guard !words.isEmpty else { return }
                    flashWords = words
                    showFlashCard = true
                }

                StudyModeCard(
                    icon: "checklist",
                    title: "选词练习",
                    subtitle: "四选一测验",
                    color: Color(red: 0.33, green: 0.78, blue: 0.62)
                ) {
                    let words = Array(vocabStore.allWords.shuffled().prefix(20))
                    guard words.count >= 4 else { return }
                    choiceWords = words
                    showChoice = true
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: 词库列表
    private var wordBooksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的词库")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(vocabStore.wordBooks) { book in
                    WordBookRow(book: book) {
                        selectedBook = book
                    } onFlash: {
                        flashWords = book.words.shuffled()
                        showFlashCard = true
                    } onQuiz: {
                        guard book.words.count >= 4 else { return }
                        choiceWords = book.words.shuffled()
                        showChoice = true
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 学习模式卡片
private struct StudyModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(color)
                Spacer()
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .frame(height: 110)
            .background(Color.quizCard)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 词库行
private struct WordBookRow: View {
    let book: WordBook
    let onTap: () -> Void
    let onFlash: () -> Void
    let onQuiz: () -> Void

    var levelColor: Color {
        switch book.level {
        case "CET-4":  return Color(red: 0.33, green: 0.62, blue: 0.93)
        case "CET-6":  return Color(red: 0.53, green: 0.40, blue: 0.88)
        case "IELTS":  return Color(red: 0.88, green: 0.55, blue: 0.25)
        default:       return Color(red: 0.33, green: 0.78, blue: 0.62)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(levelColor.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Text(book.level.prefix(1))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(levelColor)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(book.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text(book.level)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(levelColor)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(levelColor.opacity(0.15))
                                .cornerRadius(4)
                        }
                        Text("\(book.totalCount) 个单词")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }
            .buttonStyle(PlainButtonStyle())

            Divider().background(Color.quizBorder).padding(.leading, 72)

            HStack(spacing: 0) {
                ActionChip(icon: "rectangle.on.rectangle.angled", label: "闪卡", action: onFlash)
                Divider().frame(height: 20).background(Color.quizBorder)
                ActionChip(icon: "checklist", label: "选词", action: onQuiz)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color.quizCard)
        .cornerRadius(16)
    }
}

private struct ActionChip: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 13))
            }
            .foregroundColor(Color.quizPurpleLight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 词库详情（单词列表）
struct WordBookDetailView: View {
    @EnvironmentObject private var vocabStore: VocabularyStore
    let book: WordBook

    @State private var searchText = ""
    @State private var selectedWord: Word? = nil

    var filtered: [Word] {
        guard !searchText.isEmpty else { return book.words }
        return book.words.filter {
            $0.word.localizedCaseInsensitiveContains(searchText) ||
            $0.primaryMeaning.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            List {
                ForEach(filtered) { word in
                    WordListRow(word: word, record: vocabStore.wordRecord(for: word.id))
                        .listRowBackground(Color.quizCard)
                        .listRowSeparatorTint(Color.quizBorder)
                        .onTapGesture { selectedWord = word }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .searchable(text: $searchText, prompt: "搜索单词或释义")
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWord) { word in
            WordDetailSheet(word: word)
                .environmentObject(vocabStore)
        }
    }
}

// MARK: - 单词列表行
private struct WordListRow: View {
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
            if let r = record {
                Text(r.masteryLevel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(masteryColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(masteryColor.opacity(0.15))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 单词详情弹窗
struct WordDetailSheet: View {
    @EnvironmentObject private var vocabStore: VocabularyStore
    @Environment(\.dismiss) private var dismiss
    let word: Word

    var body: some View {
        NavigationStack {
            ZStack {
                Color.quizBg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 单词主体
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(word.word)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                Text(word.partOfSpeech)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.quizPurpleLight)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.quizPurple.opacity(0.2))
                                    .cornerRadius(6)
                            }
                            HStack(spacing: 10) {
                                Text(word.phonetic)
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                Button {
                                    vocabStore.speak(word.word)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color.quizPurpleLight)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        // 释义
                        VStack(alignment: .leading, spacing: 12) {
                            Text("释义")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            ForEach(Array(word.definitions.enumerated()), id: \.offset) { i, def in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(i + 1).")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color.quizPurpleLight)
                                        Text(def.meaning)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                    }
                                    if let en = def.exampleEn {
                                        Text(en)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color.quizPurpleLight.opacity(0.8))
                                            .padding(.leading, 20)
                                    }
                                    if let zh = def.exampleZh {
                                        Text(zh)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 20)
                                    }
                                }
                                .padding(12)
                                .background(Color.quizCard)
                                .cornerRadius(10)
                            }
                        }

                        // 掌握程度
                        if let record = vocabStore.wordRecord(for: word.id) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("学习状态")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                HStack(spacing: 12) {
                                    InfoChip(label: "已学", value: "\(record.studyCount) 次")
                                    InfoChip(label: "连对", value: "\(record.correctStreak) 次")
                                    InfoChip(label: "状态", value: record.masteryLevel)
                                }
                            }
                        }

                        // 标记已掌握
                        let isMastered = vocabStore.wordRecord(for: word.id)?.isMastered ?? false
                        Button {
                            vocabStore.toggleMastered(word.id)
                        } label: {
                            HStack {
                                Image(systemName: isMastered ? "checkmark.seal.fill" : "seal")
                                Text(isMastered ? "取消掌握标记" : "标记为已掌握")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isMastered ? .secondary : .quizGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background((isMastered ? Color.secondary : Color.quizGreen).opacity(0.12))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(20)
                }
            }
            .navigationTitle("单词详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(Color.quizPurpleLight)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct InfoChip: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.quizCard)
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        VocabularyHomeView()
    }
    .environmentObject(VocabularyStore())
    .preferredColorScheme(.dark)
}
