import SwiftUI
import AVFoundation

// MARK: - 闪卡学习模式
struct FlashCardView: View {
    @EnvironmentObject private var vocabStore: VocabularyStore
    @Environment(\.dismiss) private var dismiss

    let words: [Word]

    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var knownCount  = 0
    @State private var unknownCount = 0
    @State private var isFinished = false
    @State private var offset: CGFloat = 0
    @State private var dragOpacity: Double = 1.0

    private var current: Word { words[currentIndex] }
    private var progress: Double { Double(currentIndex) / Double(words.count) }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            if isFinished {
                resultView
            } else {
                VStack(spacing: 0) {
                    progressBar
                    Spacer()
                    cardView
                    Spacer()
                    actionButtons
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("闪卡记忆")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarBackButtonHidden(false)
    }

    // MARK: 进度条
    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(currentIndex + 1) / \(words.count)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Label("\(knownCount)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.quizGreen)
                    Label("\(unknownCount)", systemImage: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.quizRed)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.quizCard).frame(height: 5)
                    Capsule()
                        .fill(Color.quizPurpleLight)
                        .frame(width: geo.size.width * progress, height: 5)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: 翻卡区域
    private var cardView: some View {
        ZStack {
            // 背面（释义）
            cardBack
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.4
                )
                .opacity(isFlipped ? 1 : 0)

            // 正面（单词）
            cardFront
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.4
                )
                .opacity(isFlipped ? 0 : 1)
        }
        .offset(x: offset)
        .opacity(dragOpacity)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
        .padding(.horizontal, 24)
        .onTapGesture { withAnimation { isFlipped.toggle() } }
        .gesture(
            DragGesture()
                .onChanged { offset = $0.translation.width * 0.3 }
                .onEnded { _ in withAnimation(.spring()) { offset = 0 } }
        )
    }

    private var cardFront: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(current.partOfSpeech)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.quizPurpleLight)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.quizPurple.opacity(0.2))
                .cornerRadius(6)

            Text(current.word)
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Text(current.phonetic)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                Button {
                    vocabStore.speak(current.word)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.quizPurpleLight)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
            Text("点击翻转查看释义")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .background(Color.quizCard)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.quizBorder, lineWidth: 1)
        )
    }

    private var cardBack: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(current.word)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        vocabStore.speak(current.word)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.quizPurpleLight)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                ForEach(Array(current.definitions.enumerated()), id: \.offset) { _, def in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(def.meaning)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        if let en = def.exampleEn {
                            Text(en)
                                .font(.system(size: 13))
                                .foregroundColor(Color.quizPurpleLight.opacity(0.85))
                                .italic()
                        }
                        if let zh = def.exampleZh {
                            Text(zh)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .background(Color(red: 0.14, green: 0.14, blue: 0.20))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.quizPurple.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: 操作按钮
    private var actionButtons: some View {
        HStack(spacing: 20) {
            // 不认识
            Button {
                submitAnswer(known: false)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                    Text("不认识")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.quizRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.quizRed.opacity(0.12))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.quizRed.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // 认识
            Button {
                submitAnswer(known: true)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                    Text("认识")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.quizGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.quizGreen.opacity(0.12))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.quizGreen.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 24)
    }

    // MARK: 结果页
    private var resultView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: knownCount > unknownCount ? "star.fill" : "brain.head.profile")
                .font(.system(size: 56))
                .foregroundColor(Color.quizPurpleLight)

            VStack(spacing: 8) {
                Text("学习完成！")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                Text("共复习了 \(words.count) 个单词")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                ResultStatCard(value: "\(knownCount)", label: "认识", color: .quizGreen)
                ResultStatCard(value: "\(unknownCount)", label: "不认识", color: .quizRed)
                let pct = words.count > 0 ? Int(Double(knownCount) / Double(words.count) * 100) : 0
                ResultStatCard(value: "\(pct)%", label: "正确率", color: Color.quizPurpleLight)
            }
            .padding(.horizontal, 24)

            Spacer()
            Button("完成") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.quizPurple)
                .cornerRadius(14)
                .padding(.horizontal, 24)
        }
    }

    // MARK: 逻辑
    private func submitAnswer(known: Bool) {
        vocabStore.recordStudy(wordId: current.id, isCorrect: known)
        if known { knownCount += 1 } else { unknownCount += 1 }

        withAnimation(.easeOut(duration: 0.2)) {
            offset = known ? 300 : -300
            dragOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isFlipped = false
            offset = 0
            dragOpacity = 1
            if currentIndex < words.count - 1 {
                currentIndex += 1
            } else {
                isFinished = true
            }
        }
    }
}

private struct ResultStatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.quizCard)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        FlashCardView(words: BuiltInWords.allWords)
    }
    .environmentObject(VocabularyStore())
    .preferredColorScheme(.dark)
}
