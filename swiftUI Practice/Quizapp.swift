import SwiftUI
import QuickLook
import UIKit
import SwiftData 

// MARK: - 颜色主题

extension Color {
    static let quizPurple      = Color(red: 0.33, green: 0.29, blue: 0.72)
    static let quizPurpleLight = Color(red: 0.69, green: 0.66, blue: 0.93)
    static let quizBg          = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let quizCard        = Color(red: 0.17, green: 0.17, blue: 0.18)
    static let quizBorder      = Color(red: 0.23, green: 0.23, blue: 0.24)
    static let quizGreen       = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let quizRed         = Color(red: 0.95, green: 0.30, blue: 0.30)
}

// MARK: - ViewModel

class QuizViewModel: ObservableObject {
    let questions: [Question]

    @Published var currentIndex: Int = 0
    @Published var selectedIndex: Int? = nil
    @Published var score: Int = 0
    @Published var isFinished: Bool = false

    private(set) var userAnswers: [Int: Int] = [:]

    /// 每题答完后的回调，用于向 QuizStore 上报结果
    var onAnswer: ((UUID, Bool) -> Void)?

    init(questions: [Question]) {
        self.questions = questions
    }

    var current: Question { questions[currentIndex] }
    var progress: Double { Double(currentIndex) / Double(questions.count) }
    var isLastQuestion: Bool { currentIndex == questions.count - 1 }
    var isAnswered: Bool { selectedIndex != nil }

    func select(_ index: Int) {
        guard selectedIndex == nil else { return }
        selectedIndex = index
        userAnswers[currentIndex] = index
        let correct = index == current.correctIndex
        if correct { score += 1 }
        onAnswer?(current.id, correct)
    }

    func next() {
        if isLastQuestion { isFinished = true }
        else { currentIndex += 1; selectedIndex = nil }
    }

    func restart() {
        currentIndex = 0; selectedIndex = nil
        score = 0; isFinished = false; userAnswers = [:]
    }

    func optionState(_ index: Int) -> OptionState {
        guard let selected = selectedIndex else { return .normal }
        if index == current.correctIndex { return .correct }
        if index == selected { return .wrong }
        return .dimmed
    }

    func optionState(questionIndex qi: Int, optionIndex oi: Int) -> OptionState {
        let q = questions[qi]
        guard let selected = userAnswers[qi] else { return .normal }
        if oi == q.correctIndex { return .correct }
        if oi == selected { return .wrong }
        return .dimmed
    }

    func isCorrect(at index: Int) -> Bool {
        userAnswers[index] == questions[index].correctIndex
    }
}

enum OptionState { case normal, correct, wrong, dimmed, selected }

// MARK: - 答题容器

struct QuizContainerView: View {
    let categoryName: String
    let categoryColor: Color
    @StateObject private var vm: QuizViewModel
    @EnvironmentObject private var store: QuizStore

    init(categoryName: String, categoryColor: Color, questions: [Question]) {
        self.categoryName = categoryName
        self.categoryColor = categoryColor
        _vm = StateObject(wrappedValue: QuizViewModel(questions: questions))
    }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            if vm.isFinished {
                ResultView(vm: vm, categoryName: categoryName, categoryColor: categoryColor)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity))
            } else {
                QuizView(vm: vm)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.isFinished)
        .navigationBarBackButtonHidden(vm.isFinished)
        .onAppear {
            vm.onAnswer = { id, correct in
                store.recordAnswer(questionId: id, isCorrect: correct)
            }
        }
    }
}

// MARK: - 答题视图

struct QuizView: View {
    @ObservedObject var vm: QuizViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 进度区
            VStack(spacing: 8) {
                HStack {
                    Text("第 \(vm.currentIndex + 1) 题 / 共 \(vm.questions.count) 题")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer()
                    Text("得分 \(vm.score)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.quizPurpleLight)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.quizCard).clipShape(Capsule())
                }
                ProgressView(value: vm.progress)
                    .tint(Color.quizPurple)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 16) {
                    QuestionCard(question: vm.current)
                    VStack(spacing: 10) {
                        ForEach(0..<vm.current.options.count, id: \.self) { i in
                            OptionButton(
                                label: ["A","B","C","D"][i],
                                text: vm.current.options[i],
                                state: vm.optionState(i),
                                isAnswered: vm.isAnswered
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.select(i) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 100)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { vm.next() }
            } label: {
                Text(vm.isLastQuestion ? "查看结果" : "下一题")
                    .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(vm.isAnswered ? Color.quizPurple : Color.quizCard)
                    .cornerRadius(14)
                    .animation(.easeInOut(duration: 0.2), value: vm.isAnswered)
            }
            .disabled(!vm.isAnswered)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color.quizBg.opacity(0.95))
        }
    }
}

// MARK: - 题目卡片

struct QuestionCard: View {
    let question: Question

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.category)
                .font(.system(size: 12)).foregroundColor(Color.quizPurpleLight)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.quizPurple.opacity(0.25)).clipShape(Capsule())

            Text(question.text)
                .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)

            if let img = question.image {
                QuestionImageView(image: img)
            }

            Text("选择一个正确答案").font(.system(size: 13)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20).background(Color.quizCard).cornerRadius(16)
    }
}

// MARK: - 题目图片视图

struct QuestionImageView: View {
    let image: QuestionImageData
    @State private var isExpanded = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            imageContent.onTapGesture { isExpanded = true }
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.85))
                .padding(6).background(Color.black.opacity(0.45)).cornerRadius(6).padding(8)
        }
        .fullScreenCover(isPresented: $isExpanded) {
            ImageExpandedView(image: image, isPresented: $isExpanded)
        }
    }

    @ViewBuilder
    var imageContent: some View {
        switch image.type {
        case .asset:
            Image(image.value).resizable().scaledToFill()
                .frame(maxWidth: .infinity).frame(height: 180).clipped().cornerRadius(10)

        case .url, .file:
            AsyncImage(url: image.resolvedURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.quizBorder.opacity(0.4))
                        ProgressView().tint(Color.quizPurpleLight)
                    }.frame(height: 180)
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 180).clipped().cornerRadius(10)
                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.quizBorder.opacity(0.4))
                        VStack(spacing: 6) {
                            Image(systemName: "photo.slash").font(.system(size: 28)).foregroundColor(.secondary)
                            Text("图片加载失败").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }.frame(height: 180)
                @unknown default: EmptyView()
                }
            }
        }
    }
}

// MARK: - 全屏图片

struct ImageExpandedView: View {
    let image: QuestionImageData
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                switch image.type {
                case .asset:
                    Image(image.value).resizable().scaledToFit()
                case .url, .file:
                    AsyncImage(url: image.resolvedURL) { phase in
                        if let img = phase.image { img.resizable().scaledToFit() }
                        else { ProgressView().tint(.white) }
                    }
                }
            }
            .scaleEffect(scale)
            .gesture(MagnificationGesture()
                .onChanged { scale = max(1.0, $0) }
                .onEnded { _ in withAnimation(.spring()) { scale = 1.0 } }
            )

            VStack {
                HStack {
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30)).foregroundColor(.white.opacity(0.8)).padding()
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - 选项按钮

struct OptionButton: View {
    let label: String
    let text: String
    let state: OptionState
    let isAnswered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle().fill(badgeBg).frame(width: 30, height: 30)
                    .overlay(Text(label).font(.system(size: 14, weight: .medium)).foregroundColor(badgeFg))
                Text(text).font(.system(size: 16)).foregroundColor(textColor)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer()
                if state == .correct {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Color.quizGreen).font(.system(size: 20))
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color.quizRed).font(.system(size: 20))
                } else if state == .selected {
                    Image(systemName: "circle.fill").foregroundColor(Color.quizPurpleLight).font(.system(size: 20))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(bgColor).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: state == .normal ? 0.5 : 1.5))
        }
        .buttonStyle(PlainButtonStyle()).disabled(isAnswered)
        .scaleEffect(state == .correct || state == .wrong ? 1.02 : 1.0)
    }

    var bgColor: Color {
        switch state {
        case .correct:  Color(red: 0.13, green: 0.26, blue: 0.17)
        case .wrong:    Color(red: 0.26, green: 0.13, blue: 0.13)
        case .selected: Color(red: 0.18, green: 0.22, blue: 0.38)
        case .dimmed:   Color.quizCard.opacity(0.6)
        case .normal:   Color.quizCard
        }
    }
    var borderColor: Color {
        switch state {
        case .correct:  Color.quizGreen
        case .wrong:    Color.quizRed
        case .selected: Color.quizPurpleLight
        default:        Color.quizBorder
        }
    }
    var textColor: Color { state == .dimmed ? .secondary : .white }
    var badgeBg: Color {
        switch state {
        case .correct:  Color.quizGreen.opacity(0.3)
        case .wrong:    Color.quizRed.opacity(0.3)
        case .selected: Color.quizPurpleLight.opacity(0.3)
        default:        Color.quizBorder
        }
    }
    var badgeFg: Color {
        switch state {
        case .correct:  Color.quizGreen
        case .wrong:    Color.quizRed
        case .selected: Color.quizPurpleLight
        default:        .secondary
        }
    }
}

// MARK: - 结果视图

struct ResultView: View {
    @ObservedObject var vm: QuizViewModel
    let categoryName: String
    let categoryColor: Color
    @State private var showAnswerSheet  = false
    @State private var showPDFPreview   = false
    @State private var pdfURL: URL?     = nil
    @State private var isGeneratingPDF  = false
    @Environment(\.dismiss) private var dismiss

    var percentage: Int { Int(Double(vm.score) / Double(vm.questions.count) * 100) }

    var grade: (label: String, color: Color) {
        switch percentage {
        case 90...100: return ("太棒了！", Color.quizGreen)
        case 60..<90:  return ("不错哦～", Color.quizPurpleLight)
        default:       return ("继续努力", Color.quizRed)
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            // 环形进度
            ZStack {
                Circle().stroke(Color.quizBorder, lineWidth: 8).frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: CGFloat(percentage) / 100)
                    .stroke(categoryColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: percentage)
                VStack(spacing: 4) {
                    Text("\(vm.score)/\(vm.questions.count)")
                        .font(.system(size: 36, weight: .bold)).foregroundColor(.white)
                    Text("\(percentage)%").font(.system(size: 16)).foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text(grade.label).font(.system(size: 28, weight: .semibold)).foregroundColor(grade.color)
                Text("你答对了 \(vm.score) 道题，共 \(vm.questions.count) 题")
                    .font(.system(size: 15)).foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                StatCard(value: "\(vm.score)",                    label: "答对", color: Color.quizGreen)
                StatCard(value: "\(vm.questions.count - vm.score)", label: "答错", color: Color.quizRed)
                StatCard(value: "\(percentage)%",                 label: "正确率", color: Color.quizPurpleLight)
            }
            .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 12) {
                // 答题卡
                Button { showAnswerSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle").font(.system(size: 16))
                        Text("答题卡").font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(Color.quizPurpleLight).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.quizPurple.opacity(0.2)).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.quizPurple.opacity(0.5), lineWidth: 1))
                }

                // 导出 PDF
                Button {
                    isGeneratingPDF = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        let url = QuizPDFGenerator.generate(
                            vm: vm,
                            categoryName: categoryName,
                            percentage: percentage
                        )
                        DispatchQueue.main.async {
                            isGeneratingPDF = false
                            pdfURL = url
                            showPDFPreview = true
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isGeneratingPDF {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.richtext.fill").font(.system(size: 16))
                        }
                        Text(isGeneratingPDF ? "生成中…" : "导出 PDF")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(red: 0.20, green: 0.55, blue: 0.80)).cornerRadius(14)
                }
                .disabled(isGeneratingPDF)

                // 再来一次
                Button { dismiss() } label: {
                    Text("再来一次")
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(categoryColor).cornerRadius(14)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .sheet(isPresented: $showAnswerSheet) { AnswerSheetView(vm: vm) }
        .sheet(isPresented: $showPDFPreview) {
            if let url = pdfURL {
                PDFPreviewView(url: url)
            }
        }
    }
}

// MARK: - 答题卡

struct AnswerSheetView: View {
    @ObservedObject var vm: QuizViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedQuestionIndex: Int? = nil
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.quizBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        HStack(spacing: 20) {
                            LegendItem(color: Color.quizGreen, label: "答对")
                            LegendItem(color: Color.quizRed,   label: "答错")
                            Spacer()
                            Text("\(vm.score) / \(vm.questions.count) 题正确")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20).padding(.top, 8)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<vm.questions.count, id: \.self) { i in
                                Button { selectedQuestionIndex = i } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(vm.isCorrect(at: i) ? Color.quizGreen.opacity(0.2) : Color.quizRed.opacity(0.2))
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(vm.isCorrect(at: i) ? Color.quizGreen : Color.quizRed, lineWidth: 1.2)
                                        VStack(spacing: 4) {
                                            Text("\(i + 1)").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                                            Image(systemName: vm.isCorrect(at: i) ? "checkmark" : "xmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(vm.isCorrect(at: i) ? Color.quizGreen : Color.quizRed)
                                        }
                                    }.frame(height: 60)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("答题卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }.foregroundColor(Color.quizPurpleLight)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: Binding(
            get: { selectedQuestionIndex.map { AnswerSheetIndex(value: $0) } },
            set: { selectedQuestionIndex = $0?.value }
        )) { item in
            QuestionReviewView(vm: vm, questionIndex: item.value)
        }
    }
}

struct AnswerSheetIndex: Identifiable { let value: Int; var id: Int { value } }

struct LegendItem: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.25))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: 1))
                .frame(width: 18, height: 18)
            Text(label).font(.system(size: 13)).foregroundColor(.secondary)
        }
    }
}

// MARK: - 题目详情回顾

struct QuestionReviewView: View {
    @ObservedObject var vm: QuizViewModel
    let questionIndex: Int
    @Environment(\.dismiss) private var dismiss

    var question: Question { vm.questions[questionIndex] }
    var isCorrect: Bool { vm.isCorrect(at: questionIndex) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.quizBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(isCorrect ? Color.quizGreen : Color.quizRed)
                            Text(isCorrect ? "回答正确" : "回答错误")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isCorrect ? Color.quizGreen : Color.quizRed)
                            Spacer()
                            Text("第 \(questionIndex + 1) 题").font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(isCorrect ? Color.quizGreen.opacity(0.12) : Color.quizRed.opacity(0.12))
                        .cornerRadius(14)

                        QuestionCard(question: question)

                        VStack(spacing: 10) {
                            ForEach(0..<question.options.count, id: \.self) { i in
                                OptionButton(
                                    label: ["A","B","C","D"][i],
                                    text: question.options[i],
                                    state: vm.optionState(questionIndex: questionIndex, optionIndex: i),
                                    isAnswered: true,
                                    action: {}
                                )
                            }
                        }

                        if !isCorrect {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill").foregroundColor(.yellow).font(.system(size: 14))
                                Text("正确答案：\(["A","B","C","D"][question.correctIndex])  \(question.options[question.correctIndex])")
                                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.85))
                                Spacer()
                            }
                            .padding(14)
                            .background(Color(red: 0.20, green: 0.18, blue: 0.10))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                        }

                        // AI 解析区域预留
                        if let explanation = question.explanation {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles").foregroundColor(.yellow).font(.system(size: 14))
                                    Text("AI 解析").font(.system(size: 14, weight: .medium)).foregroundColor(.yellow)
                                }
                                Text(explanation).font(.system(size: 14)).foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .background(Color(red: 0.18, green: 0.18, blue: 0.10))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.25), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                }
            }
            .navigationTitle("题目详情").navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundColor(Color.quizPurpleLight)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct StatCard: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.quizCard).cornerRadius(12)
    }
}

// MARK: - 预览

#Preview {
    QuizContainerView(
        categoryName: "地理",
        categoryColor: Color(red: 0.20, green: 0.60, blue: 0.86),
        questions: BuiltInQuestions.geography
    )
    .environmentObject(QuizStore(modelContext: try! ModelContainer(for:
  QuestionBankEntity.self, WrongRecordEntity.self, ExamPaperEntity.self,
  AppSettingsEntity.self).mainContext))
    .preferredColorScheme(.dark)
}

// MARK: - PDF 生成器

enum QuizPDFGenerator {

    // MARK: 页面常量
    static let pageW: CGFloat  = 595.28
    static let pageH: CGFloat  = 841.89
    static let margin: CGFloat = 44.0
    static var bodyW: CGFloat  { pageW - margin * 2 }

    // MARK: 颜色
    static let colPrimary   = UIColor(white: 0.10, alpha: 1)
    static let colSecondary = UIColor(white: 0.45, alpha: 1)
    static let colAccent    = UIColor(red: 0.33, green: 0.29, blue: 0.72, alpha: 1)
    static let colGreen     = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)
    static let colRed       = UIColor(red: 0.95, green: 0.30, blue: 0.30, alpha: 1)
    static let colBg        = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1)
    static let colCard      = UIColor.white
    static let colBorder    = UIColor(white: 0.85, alpha: 1)

    // MARK: 生成入口
    static func generate(vm: QuizViewModel, categoryName: String, percentage: Int) -> URL {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
        )

        var currentY: CGFloat = margin
        var pageCtx: UIGraphicsPDFRendererContext!

        func beginPage() {
            pageCtx.beginPage()
            // 填充背景色
            colBg.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: pageW, height: pageH))
            currentY = margin
        }

        func checkBreak(neededH: CGFloat) {
            if currentY + neededH > pageH - margin {
                beginPage()
            }
        }

        let data = renderer.pdfData { ctx in
            pageCtx = ctx

            // ── 第1页：汇总 ──────────────────────────────
            beginPage()

            // 顶部装饰条
            colAccent.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: pageW, height: 6))

            currentY = 30

            // 主标题
            drawText("答题结果报告",
                     x: margin, y: currentY, width: bodyW,
                     font: .boldSystemFont(ofSize: 26),
                     color: colPrimary, alignment: .left)
            currentY += 36

            // 日期
            let dateF = DateFormatter()
            dateF.locale = Locale(identifier: "zh_CN")
            dateF.dateFormat = "yyyy年M月d日 HH:mm"
            drawText(dateF.string(from: Date()),
                     x: margin, y: currentY, width: bodyW,
                     font: .systemFont(ofSize: 12),
                     color: colSecondary, alignment: .left)
            currentY += 20

            // 分隔线
            drawLine(y: currentY, color: colBorder)
            currentY += 16

            // 分数大字（左）+ 分类标签（右对齐）
            let scoreText = "\(vm.score) / \(vm.questions.count)"
            drawText(scoreText,
                     x: margin, y: currentY, width: bodyW - 120,
                     font: .boldSystemFont(ofSize: 52),
                     color: colAccent, alignment: .left)

            // 分类标签右对齐，与分数垂直居中
            let badgeFont = UIFont.boldSystemFont(ofSize: 12)
            let badgeTxtSz = (categoryName as NSString).size(withAttributes:
                [.font: badgeFont, .foregroundColor: UIColor.white])
            let bW = badgeTxtSz.width + 24
            let bH = badgeTxtSz.height + 12
            drawBadge(text: categoryName,
                      x: pageW - margin - bW, y: currentY + (62 - bH) / 2,
                      bgColor: colAccent, textColor: .white)
            currentY += 68

            // 正确率
            drawText("\(percentage)% 正确率",
                     x: margin, y: currentY, width: bodyW,
                     font: .systemFont(ofSize: 16),
                     color: colSecondary, alignment: .left)
            currentY += 26

            // 评级
            let grade: String
            switch percentage {
            case 90...100: grade = "优秀 ✦ 太棒了！"
            case 60..<90:  grade = "良好 ✦ 不错哦～"
            default:       grade = "加油 ✦ 继续努力"
            }
            let gradeColor = percentage >= 90 ? colGreen : (percentage >= 60 ? colAccent : colRed)
            drawText(grade,
                     x: margin, y: currentY, width: bodyW,
                     font: .boldSystemFont(ofSize: 14),
                     color: gradeColor, alignment: .left)
            currentY += 38

            // 三格统计卡片（增大高度，调整文字位置）
            let cardW = (bodyW - 16) / 3
            let cardH: CGFloat = 78
            let cardY = currentY
            let stats: [(String, String, UIColor)] = [
                ("\(vm.score)",                      "答对题数", colGreen),
                ("\(vm.questions.count - vm.score)", "答错题数", colRed),
                ("\(percentage)%",                   "正确率",   colAccent),
            ]
            for (i, (val, lbl, col)) in stats.enumerated() {
                let cx = margin + CGFloat(i) * (cardW + 8)
                drawCard(x: cx, y: cardY, w: cardW, h: cardH)
                drawText(val, x: cx, y: cardY + 14, width: cardW,
                         font: .boldSystemFont(ofSize: 22), color: col, alignment: .center)
                drawText(lbl, x: cx, y: cardY + 50, width: cardW,
                         font: .systemFont(ofSize: 11), color: colSecondary, alignment: .center)
            }
            currentY = cardY + cardH + 28

            // 分隔线 + 题目列表标题
            drawLine(y: currentY, color: colBorder)
            currentY += 16
            drawText("题目详情", x: margin, y: currentY, width: bodyW,
                     font: .boldSystemFont(ofSize: 18), color: colPrimary, alignment: .left)
            currentY += 28

            // ── 逐题输出 ──────────────────────────────────
            for (qi, question) in vm.questions.enumerated() {
                let isCorrect = vm.isCorrect(at: qi)
                let userAnswer = vm.userAnswers[qi]

                // 估算此题所需高度（qW = blockW-54，选项行高 22）
                let qTextH = estimateTextHeight(question.text,
                                                width: bodyW - 54,
                                                font: .systemFont(ofSize: 13))
                let optH = CGFloat(question.options.count) * 22
                let hintH: CGFloat = isCorrect ? 0 : 16           // 错误提示行
                let blockH = 24 + qTextH + 8 + optH + hintH
                checkBreak(neededH: blockH)

                let blockX = margin
                let blockW = bodyW
                let blockY = currentY

                // 题目卡底色
                drawCard(x: blockX, y: blockY, w: blockW, h: blockH)

                // 题号（无圆圈，纯文字序号）+ 对错图标
                let circleColor = isCorrect ? colGreen : colRed
                drawText("\(qi + 1).",
                         x: blockX + 10, y: blockY + 10, width: 24,
                         font: .boldSystemFont(ofSize: 12),
                         color: circleColor, alignment: .left)

                let resultIcon = isCorrect ? "✓" : "✗"
                drawText(resultIcon,
                         x: blockX + blockW - 26, y: blockY + 10, width: 18,
                         font: .boldSystemFont(ofSize: 13),
                         color: circleColor, alignment: .center)

                // 题目文本（与选项统一缩进：blockX + 36）
                let qX = blockX + 36
                let qW = blockW - 54   // 左 36 + 右 18
                drawText(question.text,
                         x: qX, y: blockY + 8, width: qW,
                         font: .systemFont(ofSize: 13),
                         color: colPrimary, alignment: .left,
                         multiline: true)
                currentY = blockY + 8 + qTextH + 8

                // 选项（与题目文本同 x 起始，保持视觉对齐）
                for (oi, opt) in question.options.enumerated() {
                    let label = ["A", "B", "C", "D"][safe: oi] ?? ""
                    let isCorrectOpt = oi == question.correctIndex
                    let isUserOpt    = oi == userAnswer

                    let optColor: UIColor
                    if isCorrectOpt       { optColor = colGreen }
                    else if isUserOpt     { optColor = colRed }
                    else                  { optColor = colSecondary }

                    let optY = currentY

                    // 字母标签
                    drawText("\(label).",
                             x: qX, y: optY, width: 18,
                             font: .boldSystemFont(ofSize: 11),
                             color: optColor, alignment: .left)

                    // 选项文字
                    var optText = opt
                    if isCorrectOpt { optText += "  ✓" }
                    else if isUserOpt && !isCorrect { optText += "  ✗" }

                    drawText(optText,
                             x: qX + 20, y: optY, width: qW - 20,
                             font: .systemFont(ofSize: 11),
                             color: optColor, alignment: .left)

                    currentY += 22
                }

                // 若答错，加提示行
                if !isCorrect {
                    let correctLabel = ["A","B","C","D"][safe: question.correctIndex] ?? ""
                    let hintText = "正确答案：\(correctLabel). \(question.options[safe: question.correctIndex] ?? "")"
                    drawText(hintText,
                             x: qX, y: currentY, width: qW,
                             font: .italicSystemFont(ofSize: 10),
                             color: colGreen, alignment: .left)
                    currentY += 16
                }

                currentY = blockY + blockH + 10
            }

            // 底部签名
            checkBreak(neededH: 40)
            drawLine(y: currentY, color: colBorder)
            currentY += 10
            drawText("由 QuizApp 生成 · \(dateF.string(from: Date()))",
                     x: margin, y: currentY, width: bodyW,
                     font: .italicSystemFont(ofSize: 10),
                     color: colSecondary, alignment: .center)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quiz_result_\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        return url
    }

    // MARK: 绘制工具

    static func drawText(
        _ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
        font: UIFont, color: UIColor, alignment: NSTextAlignment = .left,
        multiline: Bool = false
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = multiline ? .byWordWrapping : .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let rect = CGRect(x: x, y: y, width: width,
                          height: multiline ? 10000 : font.lineHeight + 4)
        (text as NSString).draw(with: rect, options: multiline ? .usesLineFragmentOrigin : [],
                                attributes: attrs, context: nil)
    }

    static func estimateTextHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style]
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: 10000),
            options: .usesLineFragmentOrigin,
            attributes: attrs, context: nil
        )
        return ceil(rect.height) + 4
    }

    static func drawLine(y: CGFloat, color: UIColor) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageW - margin, y: y))
        color.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    static func drawCard(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        let rect = CGRect(x: x, y: y, width: w, height: h)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        colCard.setFill()
        path.fill()
        colBorder.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    static func drawCircle(x: CGFloat, y: CGFloat, diameter: CGFloat,
                            fillColor: UIColor, strokeColor: UIColor) {
        let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
        let path = UIBezierPath(ovalIn: rect)
        fillColor.setFill(); path.fill()
        strokeColor.setStroke(); path.lineWidth = 1; path.stroke()
    }

    static func drawBadge(text: String, x: CGFloat, y: CGFloat,
                           bgColor: UIColor, textColor: UIColor) {
        let font = UIFont.boldSystemFont(ofSize: 12)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let size = (text as NSString).size(withAttributes: attrs)
        let padH: CGFloat = 12, padV: CGFloat = 5
        let rect = CGRect(x: x, y: y, width: size.width + padH * 2, height: size.height + padV * 2)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
        bgColor.setFill(); path.fill()
        (text as NSString).draw(at: CGPoint(x: x + padH, y: y + padV), withAttributes: attrs)
    }
}

// MARK: - Array safe subscript（内部用）
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - PDF 预览视图

struct PDFPreviewView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let ql = QLPreviewController()
        ql.dataSource = context.coordinator
        ql.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: context.coordinator,
            action: #selector(Coordinator.share)
        )
        let nav = UINavigationController(rootViewController: ql)
        nav.navigationBar.tintColor = UIColor(Color.quizPurpleLight)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        weak var qlVC: QLPreviewController?

        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController,
                               previewItemAt index: Int) -> any QLPreviewItem {
            self.qlVC = controller
            return url as NSURL
        }

        @objc func share() {
            let ac = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = ac.popoverPresentationController {
                popover.sourceView = qlVC?.view
                popover.sourceRect = CGRect(
                    x: (qlVC?.view.bounds.midX ?? 0),
                    y: (qlVC?.view.bounds.midY ?? 0),
                    width: 0, height: 0
                )
                popover.permittedArrowDirections = []
            }
            qlVC?.present(ac, animated: true)
        }
    }
}
