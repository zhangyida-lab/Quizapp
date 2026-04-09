import SwiftUI
import QuickLook
import UIKit

// MARK: - 考试容器

struct ExamContainerView: View {
    let config: ExamConfig
    let questions: [Question]
    let questionScores: [Int]
    /// 重新作答已有试卷时传入，否则自动创建新试卷
    var existingPaperId: UUID? = nil

    @StateObject private var vm: QuizViewModel
    @EnvironmentObject private var store: QuizStore

    @State private var paperId: UUID?  = nil
    @State private var startedAt       = Date()

    init(config: ExamConfig, questions: [Question],
         questionScores: [Int], existingPaperId: UUID? = nil) {
        self.config          = config
        self.questions       = questions
        self.questionScores  = questionScores
        self.existingPaperId = existingPaperId
        _vm = StateObject(wrappedValue: QuizViewModel(questions: questions))
    }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            if vm.isFinished {
                ExamResultView(
                    vm: vm, config: config,
                    questionScores: questionScores,
                    paperId: paperId
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            } else {
                examQuizView.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.isFinished)
        .navigationBarBackButtonHidden(vm.isFinished)
        .onAppear {
            startedAt = Date()
            // 保存试卷（仅新建时）
            if let existing = existingPaperId {
                paperId = existing
            } else {
                paperId = store.saveExamPaper(
                    config: config, questions: questions, scores: questionScores
                )
            }
            vm.onAnswer = { id, correct in
                store.recordAnswer(questionId: id, isCorrect: correct)
            }
        }
        // 交卷时保存作答记录
        .onChange(of: vm.isFinished) { _, finished in
            guard finished, let pid = paperId else { return }
            let earned = questions.indices.reduce(0) { sum, i in
                sum + (vm.isCorrect(at: i) ? (questionScores[safe: i] ?? 0) : 0)
            }
            let attempt = ExamAttempt(
                startedAt: startedAt,
                finishedAt: Date(),
                answers: vm.userAnswers,
                earnedScore: earned,
                totalScore: questionScores.reduce(0, +),
                correctCount: vm.score,
                totalCount: questions.count
            )
            store.addAttempt(attempt, toPaperId: pid)
        }
    }

    // MARK: 答题界面（支持考试/练习两种模式）
    var examQuizView: some View {
        VStack(spacing: 0) {
            // 顶部进度
            VStack(spacing: 8) {
                HStack {
                    Text("第 \(vm.currentIndex + 1) 题 / 共 \(vm.questions.count) 题")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer()
                    // 本题分值 + 模式标签
                    HStack(spacing: 8) {
                        let qScore = questionScores[safe: vm.currentIndex] ?? 0
                        HStack(spacing: 3) {
                            Image(systemName: "rosette").font(.system(size: 10))
                            Text("\(qScore)分").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(Color(red: 0.86, green: 0.55, blue: 0.25))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.quizCard).clipShape(Capsule())

                        if config.examMode == .exam {
                            HStack(spacing: 3) {
                                Image(systemName: "lock.fill").font(.system(size: 9))
                                Text("考试").font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.quizCard).clipShape(Capsule())
                        }
                    }
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
                                state: examOptionState(i),
                                isAnswered: vm.isAnswered
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    vm.select(i)
                                }
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
                Text(vm.isLastQuestion ? "交卷" : "下一题")
                    .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(vm.isAnswered ? Color.quizPurple : Color.quizCard).cornerRadius(14)
                    .animation(.easeInOut(duration: 0.2), value: vm.isAnswered)
            }
            .disabled(!vm.isAnswered)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color.quizBg.opacity(0.95))
        }
    }

    /// 考试模式：选中但不揭示对错；练习模式：立即显示对错
    func examOptionState(_ index: Int) -> OptionState {
        if config.examMode == .exam {
            guard let selected = vm.selectedIndex else { return .normal }
            if index == selected { return .selected }
            return vm.isAnswered ? .dimmed : .normal
        }
        return vm.optionState(index)
    }
}

// MARK: - 考试结果视图

struct ExamResultView: View {
    @ObservedObject var vm: QuizViewModel
    let config: ExamConfig
    let questionScores: [Int]
    let paperId: UUID?

    @State private var showDetail   = false
    @State private var showPDF      = false
    @State private var pdfURL: URL? = nil
    @State private var isGenPDF     = false
    @Environment(\.dismiss) private var dismiss

    var earnedScore: Int {
        vm.questions.indices.reduce(0) { sum, i in
            sum + (vm.isCorrect(at: i) ? (questionScores[safe: i] ?? 0) : 0)
        }
    }
    var totalScore:  Int { questionScores.reduce(0, +) }
    var percentage:  Int {
        guard totalScore > 0 else { return 0 }
        return Int(Double(earnedScore) / Double(totalScore) * 100)
    }
    var grade: (label: String, color: Color) {
        switch percentage {
        case 90...100: return ("优秀", Color.quizGreen)
        case 75..<90:  return ("良好", Color.quizPurpleLight)
        case 60..<75:  return ("及格", Color(red: 0.86, green: 0.55, blue: 0.25))
        default:       return ("不及格", Color.quizRed)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 16)
                scoreRing
                gradeSection
                statsRow
                detailToggle
                if showDetail { questionDetailList }
                actionButtons
                Spacer(minLength: 20)
            }
        }
        .background(Color.quizBg.ignoresSafeArea())
        .navigationTitle("考试结果")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showPDF) {
            if let url = pdfURL { PDFPreviewView(url: url) }
        }
    }

    var scoreRing: some View {
        ZStack {
            Circle().stroke(Color.quizBorder, lineWidth: 10).frame(width: 180, height: 180)
            Circle()
                .trim(from: 0, to: CGFloat(percentage) / 100)
                .stroke(grade.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: percentage)
            VStack(spacing: 4) {
                Text("\(earnedScore)")
                    .font(.system(size: 48, weight: .bold)).foregroundColor(.white)
                Text("/ \(totalScore) 分").font(.system(size: 15)).foregroundColor(.secondary)
            }
        }
    }

    var gradeSection: some View {
        VStack(spacing: 6) {
            Text(grade.label)
                .font(.system(size: 30, weight: .bold)).foregroundColor(grade.color)
            Text("正确率 \(percentage)%  ·  答对 \(vm.score) / \(vm.questions.count) 题")
                .font(.system(size: 14)).foregroundColor(.secondary)
        }
    }

    var statsRow: some View {
        HStack(spacing: 12) {
            ExamStatCard(value: "\(earnedScore)",               label: "得分",   color: grade.color)
            ExamStatCard(value: "\(totalScore - earnedScore)",  label: "失分",   color: Color.quizRed)
            ExamStatCard(value: "\(vm.questions.count - vm.score)", label: "答错题", color: Color(red: 0.86, green: 0.55, blue: 0.25))
        }
        .padding(.horizontal, 20)
    }

    var detailToggle: some View {
        Button { showDetail.toggle() } label: {
            HStack {
                Text("逐题得分明细")
                    .font(.system(size: 14, weight: .medium)).foregroundColor(Color.quizPurpleLight)
                Spacer()
                Image(systemName: showDetail ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(14).background(Color.quizCard).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizBorder, lineWidth: 0.5))
        }
        .buttonStyle(PlainButtonStyle()).padding(.horizontal, 20)
    }

    var questionDetailList: some View {
        VStack(spacing: 8) {
            ForEach(Array(vm.questions.enumerated()), id: \.offset) { i, q in
                let correct  = vm.isCorrect(at: i)
                let earned   = correct ? (questionScores[safe: i] ?? 0) : 0
                let possible = questionScores[safe: i] ?? 0
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(correct ? Color.quizGreen.opacity(0.15) : Color.quizRed.opacity(0.15))
                            .frame(width: 30, height: 30)
                        Text("\(i + 1)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(correct ? Color.quizGreen : Color.quizRed)
                    }
                    Text(q.text).font(.system(size: 13)).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Text("\(earned)/\(possible)分")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(correct ? Color.quizGreen : Color.quizRed)
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(correct ? Color.quizGreen : Color.quizRed)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.quizCard).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 20)
    }

    var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                isGenPDF = true
                DispatchQueue.global(qos: .userInitiated).async {
                    let url = ExamPDFGenerator.generate(
                        vm: vm, config: config,
                        questionScores: questionScores,
                        earnedScore: earnedScore,
                        totalScore: totalScore,
                        percentage: percentage,
                        grade: grade.label
                    )
                    DispatchQueue.main.async { isGenPDF = false; pdfURL = url; showPDF = true }
                }
            } label: {
                HStack(spacing: 8) {
                    if isGenPDF { ProgressView().tint(.white).scaleEffect(0.8) }
                    else { Image(systemName: "doc.richtext.fill").font(.system(size: 15)) }
                    Text(isGenPDF ? "生成中…" : "导出成绩单 PDF")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Color(red: 0.20, green: 0.55, blue: 0.80)).cornerRadius(14)
            }
            .buttonStyle(PlainButtonStyle()).disabled(isGenPDF)

            Button { dismiss() } label: {
                Text("完成")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Color.quizPurple).cornerRadius(14)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 考试成绩单 PDF 生成器

enum ExamPDFGenerator {
    static let pageW: CGFloat  = 595.28
    static let pageH: CGFloat  = 841.89
    static let margin: CGFloat = 44.0
    static var bodyW: CGFloat  { pageW - margin * 2 }

    static let colPrimary   = UIColor(white: 0.10, alpha: 1)
    static let colSecondary = UIColor(white: 0.45, alpha: 1)
    static let colAccent    = UIColor(red: 0.33, green: 0.29, blue: 0.72, alpha: 1)
    static let colGreen     = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)
    static let colRed       = UIColor(red: 0.95, green: 0.30, blue: 0.30, alpha: 1)
    static let colOrange    = UIColor(red: 0.86, green: 0.55, blue: 0.25, alpha: 1)
    static let colBg        = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1)
    static let colCard      = UIColor.white
    static let colBorder    = UIColor(white: 0.85, alpha: 1)

    static func generate(
        vm: QuizViewModel, config: ExamConfig, questionScores: [Int],
        earnedScore: Int, totalScore: Int, percentage: Int, grade: String
    ) -> URL {
        var y: CGFloat = margin
        var ctx: UIGraphicsPDFRendererContext!

        func newPage() {
            ctx.beginPage()
            colBg.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: pageW, height: pageH))
            y = margin
        }
        func need(_ h: CGFloat) { if y + h > pageH - margin { newPage() } }

        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)).pdfData { c in
            ctx = c; newPage()
            colAccent.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: pageW, height: 6))
            y = 28

            drawTxt("考试成绩单", x: margin, y: y, w: bodyW, font: .boldSystemFont(ofSize: 26), color: colPrimary); y += 36

            let df = DateFormatter(); df.locale = Locale(identifier: "zh_CN"); df.dateFormat = "yyyy年M月d日 HH:mm"
            drawTxt(df.string(from: Date()), x: margin, y: y, w: bodyW, font: .systemFont(ofSize: 12), color: colSecondary); y += 22
            drawLine(y: y); y += 14

            let subjects = config.subjects.sorted().joined(separator: "  ")
            let modeText = config.examMode.rawValue
            drawTxt("科目：\(subjects)  ·  \(modeText)", x: margin, y: y, w: bodyW, font: .systemFont(ofSize: 13), color: colSecondary); y += 20
            drawTxt("共 \(vm.questions.count) 题 · 总分 \(totalScore) 分", x: margin, y: y, w: bodyW, font: .systemFont(ofSize: 13), color: colSecondary); y += 26

            let gc = percentage >= 90 ? colGreen : (percentage >= 75 ? colAccent : (percentage >= 60 ? colOrange : colRed))
            drawTxt("\(earnedScore) 分", x: margin, y: y, w: bodyW, font: .boldSystemFont(ofSize: 56), color: gc); y += 70
            drawTxt("总分 \(totalScore) 分  ·  正确率 \(percentage)%  ·  评级：\(grade)",
                    x: margin, y: y, w: bodyW, font: .systemFont(ofSize: 14), color: colSecondary); y += 30

            let cw = (bodyW - 16) / 3; let ch: CGFloat = 64; let cy = y
            let stats: [(String, String, UIColor)] = [("\(vm.score)", "答对题数", colGreen), ("\(vm.questions.count - vm.score)", "答错题数", colRed), ("\(totalScore - earnedScore)", "失分", colOrange)]
            for (i, (v, l, c)) in stats.enumerated() {
                let x = margin + CGFloat(i) * (cw + 8)
                drawCard(x: x, y: cy, w: cw, h: ch)
                drawTxt(v, x: x, y: cy + 8, w: cw, font: .boldSystemFont(ofSize: 22), color: c, align: .center)
                drawTxt(l, x: x, y: cy + 36, w: cw, font: .systemFont(ofSize: 11), color: colSecondary, align: .center)
            }
            y = cy + ch + 28; drawLine(y: y); y += 14
            drawTxt("逐题得分明细", x: margin, y: y, w: bodyW, font: .boldSystemFont(ofSize: 16), color: colPrimary); y += 26

            for (i, q) in vm.questions.enumerated() {
                let correct  = vm.isCorrect(at: i)
                let earned   = correct ? (questionScores[safe: i] ?? 0) : 0
                let possible = questionScores[safe: i] ?? 0
                let qH = estimateH(q.text, w: bodyW - 60, font: .systemFont(ofSize: 12))
                let bH = max(48, qH + 28)
                need(bH + 8); drawCard(x: margin, y: y, w: bodyW, h: bH)
                let cc = correct ? colGreen : colRed
                drawCircle(x: margin + 10, y: y + (bH - 22) / 2, d: 22, fill: cc.withAlphaComponent(0.15), stroke: cc)
                drawTxt("\(i+1)", x: margin + 10, y: y + (bH - 22) / 2 + 3, w: 22, font: .boldSystemFont(ofSize: 10), color: cc, align: .center)
                drawTxt(q.text, x: margin + 38, y: y + 8, w: bodyW - 100, font: .systemFont(ofSize: 12), color: colPrimary, multi: true)
                drawTxt("\(earned)/\(possible)分", x: margin + bodyW - 60, y: y + (bH - 16) / 2, w: 52, font: .boldSystemFont(ofSize: 13), color: cc, align: .right)
                y += bH + 8
            }
            need(30); drawLine(y: y); y += 10
            drawTxt("由 QuizApp 生成 · \(df.string(from: Date()))", x: margin, y: y, w: bodyW, font: .italicSystemFont(ofSize: 10), color: colSecondary, align: .center)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("exam_\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        return url
    }

    static func drawTxt(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat,
                         font: UIFont, color: UIColor, align: NSTextAlignment = .left, multi: Bool = false) {
        let style = NSMutableParagraphStyle(); style.alignment = align
        style.lineBreakMode = multi ? .byWordWrapping : .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        let rect = CGRect(x: x, y: y, width: w, height: multi ? 10000 : font.lineHeight + 4)
        (text as NSString).draw(with: rect, options: multi ? .usesLineFragmentOrigin : [], attributes: attrs, context: nil)
    }
    static func estimateH(_ text: String, w: CGFloat, font: UIFont) -> CGFloat {
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style]
        let r = (text as NSString).boundingRect(with: CGSize(width: w, height: 10000), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        return ceil(r.height)
    }
    static func drawLine(y: CGFloat) {
        let p = UIBezierPath(); p.move(to: CGPoint(x: margin, y: y)); p.addLine(to: CGPoint(x: pageW - margin, y: y))
        colBorder.setStroke(); p.lineWidth = 0.5; p.stroke()
    }
    static func drawCard(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        let p = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 8)
        colCard.setFill(); p.fill(); colBorder.setStroke(); p.lineWidth = 0.5; p.stroke()
    }
    static func drawCircle(x: CGFloat, y: CGFloat, d: CGFloat, fill: UIColor, stroke: UIColor) {
        let p = UIBezierPath(ovalIn: CGRect(x: x, y: y, width: d, height: d))
        fill.setFill(); p.fill(); stroke.setStroke(); p.lineWidth = 1; p.stroke()
    }
}

// MARK: - 空白试卷 PDF 生成器（白底，适合打印）

enum BlankExamPDFGenerator {
    static let pageW: CGFloat  = 595.28
    static let pageH: CGFloat  = 841.89
    static let margin: CGFloat = 48.0
    static var bodyW: CGFloat  { pageW - margin * 2 }

    static let colPrimary   = UIColor(white: 0.08, alpha: 1)
    static let colSecondary = UIColor(white: 0.42, alpha: 1)
    static let colAccent    = UIColor(red: 0.28, green: 0.24, blue: 0.68, alpha: 1)
    static let colBorder    = UIColor(white: 0.80, alpha: 1)
    static let colLightBg   = UIColor(white: 0.96, alpha: 1)

    static func generate(config: ExamConfig, questions: [Question], questionScores: [Int]) -> URL {
        var y: CGFloat = margin
        var pageNum    = 1
        var ctx: UIGraphicsPDFRendererContext!

        func newPage() {
            ctx.beginPage()
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: pageW, height: pageH))
            // 顶部色条
            colAccent.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: pageW, height: 4))
            // 页脚
            let footer = "第 \(pageNum) 页 / 共 \(estimatePageCount(questions: questions)) 页"
            drawTxt(footer, x: margin, y: pageH - 28, w: bodyW,
                    font: .systemFont(ofSize: 9), color: colSecondary, align: .center)
            pageNum += 1
            y = margin + 10
        }

        func need(_ h: CGFloat) { if y + h > pageH - 40 { newPage() } }

        let data = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
        ).pdfData { c in
            ctx = c; newPage()

            // ── 标题区 ──
            let title = config.autoTitle(actualCount: questions.count)
            drawTxt(title, x: margin, y: y, w: bodyW,
                    font: .boldSystemFont(ofSize: 22), color: colPrimary, align: .center)
            y += 32

            let df = DateFormatter()
            df.locale = Locale(identifier: "zh_CN")
            df.dateFormat = "yyyy年M月d日"
            let meta = "科目：\(config.subjects.sorted().joined(separator: "、"))    " +
                       "总分：\(config.totalScore) 分    " +
                       "日期：\(df.string(from: Date()))"
            drawTxt(meta, x: margin, y: y, w: bodyW,
                    font: .systemFont(ofSize: 11), color: colSecondary, align: .center)
            y += 18

            drawLine(y: y, color: colAccent, width: 1.2); y += 8

            let instr = "注意事项：每题只有一个正确答案，请在对应选项上画圈。答题时间请合理分配。"
            drawTxt(instr, x: margin, y: y, w: bodyW,
                    font: .italicSystemFont(ofSize: 10), color: colSecondary)
            y += 22

            drawLine(y: y, color: colBorder, width: 0.5); y += 16

            // ── 题目列表 ──
            let labels = ["A", "B", "C", "D"]
            for (i, q) in questions.enumerated() {
                let score = questionScores[safe: i] ?? 0

                // 题号行高度估算
                let qTextH = estimateH(q.text, w: bodyW - 28, font: .systemFont(ofSize: 12))
                let optionsH = q.options.enumerated().reduce(CGFloat(0)) { sum, pair in
                    sum + max(18, estimateH(pair.element, w: bodyW - 60,
                                           font: .systemFont(ofSize: 11)) + 4)
                }
                let blockH = 24 + qTextH + 10 + optionsH + 28
                need(blockH)

                // 题号 + 分值标签
                let numStr = "\(i + 1)."
                drawTxt(numStr, x: margin, y: y, w: 22,
                        font: .boldSystemFont(ofSize: 12), color: colPrimary)
                let scoreTag = "(\(score)分)"
                drawTxt(scoreTag, x: pageW - margin - 36, y: y, w: 36,
                        font: .systemFont(ofSize: 10), color: colSecondary, align: .right)

                // 题目文字
                drawTxt(q.text, x: margin + 24, y: y, w: bodyW - 60,
                        font: .systemFont(ofSize: 12), color: colPrimary, multi: true)
                y += qTextH + 10

                // 选项
                for (j, opt) in q.options.enumerated() {
                    let label = labels[safe: j] ?? ""
                    let optH = max(18, estimateH(opt, w: bodyW - 60,
                                                 font: .systemFont(ofSize: 11)) + 4)
                    // 选项：字母 + 文字同基线对齐，无圆圈
                    drawTxt("\(label).", x: margin + 24, y: y, w: 18,
                            font: .boldSystemFont(ofSize: 11), color: colSecondary)
                    drawTxt(opt, x: margin + 44, y: y, w: bodyW - 68,
                            font: .systemFont(ofSize: 11), color: colPrimary, multi: true)
                    y += optH
                }

                // 答题框
                y += 6
                drawLine(y: y, color: colBorder, width: 0.5); y += 5
                drawTxt("我的答案：___", x: margin + 24, y: y, w: 120,
                        font: .systemFont(ofSize: 10), color: colSecondary)
                y += 20
                drawLine(y: y, color: colLightBg, width: 0.5)
                y += 14
            }

            // ── 答案汇总页 ──
            newPage()
            drawTxt("参考答案", x: margin, y: y, w: bodyW,
                    font: .boldSystemFont(ofSize: 16), color: colPrimary)
            y += 8
            drawLine(y: y, color: colAccent, width: 1); y += 14

            let cols = 5
            let cellW = bodyW / CGFloat(cols)
            let cellH: CGFloat = 28

            for (i, q) in questions.enumerated() {
                let col = i % cols
                let row = i / cols
                let cx  = margin + CGFloat(col) * cellW
                let cy  = y + CGFloat(row) * cellH

                need(cellH)

                let answerLabel = ["A", "B", "C", "D"][safe: q.correctIndex] ?? "?"
                let cell = "\(i + 1). \(answerLabel)"
                let bgColor = i % 2 == 0 ? colLightBg : UIColor.white
                bgColor.setFill()
                UIRectFill(CGRect(x: cx, y: cy, width: cellW, height: cellH - 2))
                drawTxt(cell, x: cx + 4, y: cy + 6, w: cellW - 8,
                        font: .systemFont(ofSize: 12), color: colPrimary)
            }
            y += CGFloat((questions.count + cols - 1) / cols) * cellH + 16

            drawLine(y: y, color: colBorder, width: 0.5); y += 10
            drawTxt("由 QuizApp 生成 · \(df.string(from: Date()))",
                    x: margin, y: y, w: bodyW,
                    font: .italicSystemFont(ofSize: 9), color: colSecondary, align: .center)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("blank_exam_\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        return url
    }

    // 粗略估算总页数（用于页脚显示）
    private static func estimatePageCount(questions: [Question]) -> Int {
        max(2, questions.count / 5 + 2)
    }

    static func drawTxt(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat,
                        font: UIFont, color: UIColor,
                        align: NSTextAlignment = .left, multi: Bool = false) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = multi ? .byWordWrapping : .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ]
        let rect = CGRect(x: x, y: y, width: w,
                          height: multi ? 10000 : font.lineHeight + 4)
        (text as NSString).draw(with: rect,
                                options: multi ? .usesLineFragmentOrigin : [],
                                attributes: attrs, context: nil)
    }

    static func estimateH(_ text: String, w: CGFloat, font: UIFont) -> CGFloat {
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style]
        let r = (text as NSString).boundingRect(
            with: CGSize(width: w, height: 10000),
            options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        return ceil(r.height)
    }

    static func drawLine(y: CGFloat, color: UIColor, width: CGFloat) {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: margin, y: y))
        p.addLine(to: CGPoint(x: pageW - margin, y: y))
        color.setStroke(); p.lineWidth = width; p.stroke()
    }

    static func drawCircle(x: CGFloat, y: CGFloat, d: CGFloat,
                           fill: UIColor, stroke: UIColor) {
        let p = UIBezierPath(ovalIn: CGRect(x: x, y: y, width: d, height: d))
        fill.setFill(); p.fill(); stroke.setStroke(); p.lineWidth = 0.8; p.stroke()
    }
}

// MARK: - 辅助组件
struct ExamStatCard: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.quizCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizBorder, lineWidth: 0.5))
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

#Preview {
    NavigationStack {
        ExamContainerView(
            config: ExamConfig(subjects: ["地理"], difficulties: [1,2,3,4,5],
                               totalCount: 3, totalScore: 100,
                               scoreMode: .uniform, examMode: .practice),
            questions: Array(BuiltInQuestions.geography.prefix(3)),
            questionScores: [34, 33, 33]
        )
    }
    .environmentObject(QuizStore())
    .preferredColorScheme(.dark)
}
