import SwiftUI

// MARK: - 选词练习（四选一）
struct WordChoiceView: View {
    @EnvironmentObject private var vocabStore: VocabularyStore
    @Environment(\.dismiss) private var dismiss

    let words: [Word]
    let allWords: [Word]

    @StateObject private var vm: WordChoiceViewModel

    init(words: [Word], allWords: [Word]) {
        self.words = words
        self.allWords = allWords
        _vm = StateObject(wrappedValue: WordChoiceViewModel(words: words, allWords: allWords))
    }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            if vm.isFinished {
                resultView
            } else {
                quizContent
            }
        }
        .navigationTitle("选词练习")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: 答题界面
    private var quizContent: some View {
        VStack(spacing: 0) {
            // 进度
            HStack {
                Text("\(vm.currentIndex + 1) / \(vm.items.count)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Text("得分 \(vm.score)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.quizPurpleLight)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.quizCard).frame(height: 5)
                    Capsule()
                        .fill(Color.quizPurpleLight)
                        .frame(width: geo.size.width * vm.progress, height: 5)
                        .animation(.easeInOut(duration: 0.3), value: vm.progress)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 24)
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    questionCard
                    optionsSection
                    if vm.selectedIndex != nil {
                        explanationArea
                        nextButton
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: 题目卡片
    private var questionCard: some View {
        let item = vm.currentItem
        return VStack(spacing: 12) {
            Text("这个单词的意思是？")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Text(item.word.word)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                Button {
                    vocabStore.speak(item.word.word)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.quizPurpleLight)
                }
                .buttonStyle(PlainButtonStyle())
            }

            HStack(spacing: 8) {
                Text(item.word.phonetic)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                Text(item.word.partOfSpeech)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.quizPurpleLight)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.quizPurple.opacity(0.2))
                    .cornerRadius(5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.quizCard)
        .cornerRadius(16)
    }

    // MARK: 选项
    private var optionsSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(vm.currentItem.options.enumerated()), id: \.offset) { idx, opt in
                OptionButton(
                    label: "\(["A","B","C","D"][idx]).",
                    text: opt,
                    state: vm.optionState(idx),
                    isAnswered: vm.selectedIndex != nil
                ) {
                    vm.select(idx)
                    vocabStore.recordStudy(wordId: vm.currentItem.word.id,
                                          isCorrect: idx == vm.currentItem.correctIndex)
                }
            }
        }
    }

    // MARK: 解析
    private var explanationArea: some View {
        let correct = vm.currentItem.correctIndex == vm.selectedIndex
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(correct ? .quizGreen : .quizRed)
                Text(correct ? "回答正确！" : "回答错误")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(correct ? .quizGreen : .quizRed)
            }
            if let def = vm.currentItem.word.definitions.first {
                Text("正确答案：\(def.meaning)")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                if let ex = def.exampleEn {
                    Text(ex)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background((correct ? Color.quizGreen : Color.quizRed).opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((correct ? Color.quizGreen : Color.quizRed).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: 下一题
    private var nextButton: some View {
        Button(vm.isLastQuestion ? "查看结果" : "下一题") {
            vm.next()
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.quizPurple)
        .cornerRadius(12)
    }

    // MARK: 结果页
    private var resultView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: vm.score >= vm.items.count / 2 ? "star.fill" : "arrow.counterclockwise")
                .font(.system(size: 56))
                .foregroundColor(Color.quizPurpleLight)

            VStack(spacing: 8) {
                Text("练习结束！")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                Text("共 \(vm.items.count) 题，答对 \(vm.score) 题")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                ResultStatCard2(value: "\(vm.score)", label: "答对", color: .quizGreen)
                ResultStatCard2(value: "\(vm.items.count - vm.score)", label: "答错", color: .quizRed)
                let pct = vm.items.count > 0 ? Int(Double(vm.score) / Double(vm.items.count) * 100) : 0
                ResultStatCard2(value: "\(pct)%", label: "正确率", color: Color.quizPurpleLight)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button("再练一次") {
                    vm.restart(words: words, allWords: allWords)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.quizPurple)
                .cornerRadius(14)

                Button { dismiss() } label: {
                    Text("完成")
                        .font(.system(size: 15))
                        .foregroundColor(Color.quizPurpleLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.quizCard)
                        .cornerRadius(14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: 属性帮助
    private var isLastQuestion: Bool { vm.currentIndex == vm.items.count - 1 }
}

// MARK: - Quiz Item
struct WordQuizItem {
    let word: Word
    let options: [String]
    let correctIndex: Int
}

// MARK: - ViewModel
class WordChoiceViewModel: ObservableObject {
    @Published private(set) var items: [WordQuizItem] = []
    @Published var currentIndex = 0
    @Published var selectedIndex: Int? = nil
    @Published var score = 0
    @Published var isFinished = false

    var currentItem: WordQuizItem { items[currentIndex] }
    var progress: Double { Double(currentIndex) / Double(items.count) }
    var isLastQuestion: Bool { currentIndex == items.count - 1 }

    init(words: [Word], allWords: [Word]) {
        items = Self.buildItems(words: words, allWords: allWords)
    }

    func select(_ idx: Int) {
        guard selectedIndex == nil else { return }
        selectedIndex = idx
        if idx == currentItem.correctIndex { score += 1 }
    }

    func next() {
        if isLastQuestion {
            isFinished = true
        } else {
            currentIndex += 1
            selectedIndex = nil
        }
    }

    func restart(words: [Word], allWords: [Word]) {
        items = Self.buildItems(words: words, allWords: allWords)
        currentIndex = 0; selectedIndex = nil; score = 0; isFinished = false
    }

    func optionState(_ idx: Int) -> OptionState {
        guard let sel = selectedIndex else { return .normal }
        if idx == currentItem.correctIndex { return .correct }
        if idx == sel { return .wrong }
        return .dimmed
    }

    private static func buildItems(words: [Word], allWords: [Word]) -> [WordQuizItem] {
        words.shuffled().map { word in
            let correct = word.primaryMeaning
            var distractors = allWords
                .filter { $0.id != word.id && !$0.primaryMeaning.isEmpty }
                .shuffled()
                .prefix(3)
                .map { $0.primaryMeaning }
            while distractors.count < 3 {
                distractors.append("无")
            }
            var allOpts = [correct] + distractors
            allOpts.shuffle()
            let ci = allOpts.firstIndex(of: correct) ?? 0
            return WordQuizItem(word: word, options: allOpts, correctIndex: ci)
        }
    }
}

private struct ResultStatCard2: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.quizCard)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        WordChoiceView(words: BuiltInWords.allWords, allWords: BuiltInWords.allWords)
    }
    .environmentObject(VocabularyStore())
    .preferredColorScheme(.dark)
}
