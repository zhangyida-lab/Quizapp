//
//  QuestionImage.swift
//  swiftUI Practice
//
//  Created by tony on 4/6/26.
//



import SwiftUI

// MARK: - 数据模型

/// 题目图片来源，支持本地 Assets 和远程 URL 两种方式
enum QuestionImage {
    case asset(String)   // Assets.xcassets 中的图片名称
    case url(String)     // 远程图片 URL 字符串
}

struct Question: Identifiable {
    let id = UUID()
    let category: String
    let text: String
    let image: QuestionImage?   // 可选图片，nil 表示纯文字题
    let options: [String]
    let correctIndex: Int
}

// MARK: - 完整题库

let allQuestions: [Question] = [

    // ---- 地理 ----
    Question(category: "地理", text: "中国的首都是哪里？", image: nil,
             options: ["上海", "北京", "广州", "成都"], correctIndex: 1),
    Question(category: "地理", text: "世界上面积最大的国家是？", image: nil,
             options: ["中国", "美国", "俄罗斯", "加拿大"], correctIndex: 2),
    Question(category: "地理", text: "尼罗河流经哪个大洲？", image: nil,
             options: ["亚洲", "欧洲", "非洲", "南美洲"], correctIndex: 2),
    Question(category: "地理", text: "世界上最高的山峰是？", image: nil,
             options: ["K2", "珠穆朗玛峰", "乔戈里峰", "洛子峰"], correctIndex: 1),
    Question(category: "地理", text: "澳大利亚的首都是？", image: nil,
             options: ["悉尼", "墨尔本", "布里斯班", "堪培拉"], correctIndex: 3),
    Question(category: "地理", text: "以下哪个国家不属于东南亚？", image: nil,
             options: ["泰国", "越南", "印度", "马来西亚"], correctIndex: 2),

    // ---- 科学 ----
    Question(category: "科学", text: "图中所示是哪个天体？",
             image: .url("https://upload.wikimedia.org/wikipedia/commons/thumb/9/97/The_Earth_seen_from_Apollo_17.jpg/600px-The_Earth_seen_from_Apollo_17.jpg"),
             options: ["火星", "金星", "地球", "木星"], correctIndex: 2),
    Question(category: "科学", text: "地球距离太阳大约多少公里？", image: nil,
             options: ["约 1.5 亿公里", "约 3.8 亿公里", "约 5.0 亿公里", "约 1.0 亿公里"], correctIndex: 0),
    Question(category: "科学", text: "水的化学式是？", image: nil,
             options: ["CO₂", "H₂O", "O₂", "NaCl"], correctIndex: 1),
    Question(category: "科学", text: "光在真空中的速度约为？", image: nil,
             options: ["30 万 km/s", "3 万 km/s", "300 万 km/s", "3000 km/s"], correctIndex: 0),
    Question(category: "科学", text: "DNA 的全称是？", image: nil,
             options: ["脱氧核糖核酸", "核糖核酸", "氨基酸", "腺嘌呤"], correctIndex: 0),
    Question(category: "科学", text: "以下哪种元素是金属？", image: nil,
             options: ["氧", "氮", "氢", "铁"], correctIndex: 3),

    // ---- 历史 ----
    Question(category: "历史", text: "中国四大发明不包括以下哪项？", image: nil,
             options: ["造纸术", "指南针", "望远镜", "印刷术"], correctIndex: 2),
    Question(category: "历史", text: "第一次世界大战爆发于哪一年？", image: nil,
             options: ["1904", "1914", "1918", "1939"], correctIndex: 1),
    Question(category: "历史", text: "秦始皇统一六国是在公元前哪一年？", image: nil,
             options: ["公元前 256 年", "公元前 221 年", "公元前 206 年", "公元前 180 年"], correctIndex: 1),
    Question(category: "历史", text: "文艺复兴运动最早发源于哪个国家？", image: nil,
             options: ["法国", "英国", "意大利", "德国"], correctIndex: 2),
    Question(category: "历史", text: "以下哪位人物与美国独立战争直接相关？", image: nil,
             options: ["拿破仑", "乔治·华盛顿", "俾斯麦", "克伦威尔"], correctIndex: 1),
    Question(category: "历史", text: "中国哪个朝代修建了长城的主体部分？", image: nil,
             options: ["汉朝", "唐朝", "明朝", "清朝"], correctIndex: 2),

    // ---- 数学 ----
    Question(category: "数学", text: "π（圆周率）约等于多少？", image: nil,
             options: ["3.1216", "3.1416", "3.1516", "3.1616"], correctIndex: 1),
    Question(category: "数学", text: "2 的 10 次方等于？", image: nil,
             options: ["512", "1024", "2048", "256"], correctIndex: 1),
    Question(category: "数学", text: "直角三角形中，斜边的平方等于？", image: nil,
             options: ["两直角边之积", "两直角边之和", "两直角边平方之和", "两直角边平方之差"], correctIndex: 2),
    Question(category: "数学", text: "以下哪个数是质数？", image: nil,
             options: ["9", "15", "21", "29"], correctIndex: 3),
    Question(category: "数学", text: "一个正六边形的内角和是多少度？", image: nil,
             options: ["360°", "540°", "720°", "900°"], correctIndex: 2),
    Question(category: "数学", text: "下列哪个是无理数？", image: nil,
             options: ["0.5", "√2", "1/3", "0.333..."], correctIndex: 1),

    // ---- 艺术 ----
    Question(category: "艺术", text: "以下哪幅是梵高的作品《星夜》？",
             image: .url("https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg/600px-Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg"),
             options: ["蒙娜丽莎", "星夜", "呐喊", "睡莲"], correctIndex: 1),
    Question(category: "艺术", text: "《蒙娜丽莎》是哪位艺术家的作品？", image: nil,
             options: ["米开朗基罗", "拉斐尔", "达芬奇", "波提切利"], correctIndex: 2),
    Question(category: "艺术", text: "贝多芬的第几号交响曲又称《命运》？", image: nil,
             options: ["第五号", "第六号", "第七号", "第九号"], correctIndex: 0),
    Question(category: "艺术", text: "中国传统绘画中"文人画"最注重的是？", image: nil,
             options: ["色彩浓烈", "写实造型", "意境与笔墨", "透视准确"], correctIndex: 2),
    Question(category: "艺术", text: "以下哪位是印象派代表画家？", image: nil,
             options: ["毕加索", "莫奈", "达利", "安迪·沃霍尔"], correctIndex: 1),
    Question(category: "艺术", text: "芭蕾舞起源于哪个国家？", image: nil,
             options: ["俄罗斯", "法国", "意大利", "西班牙"], correctIndex: 2),

    // ---- 体育 ----
    Question(category: "体育", text: "FIFA 世界杯多少年举办一次？", image: nil,
             options: ["2 年", "3 年", "4 年", "5 年"], correctIndex: 2),
    Question(category: "体育", text: "奥运会五环旗的颜色不包括？", image: nil,
             options: ["红色", "紫色", "蓝色", "黑色"], correctIndex: 1),
    Question(category: "体育", text: "标准马拉松比赛的距离约为？", image: nil,
             options: ["21 公里", "42.195 公里", "50 公里", "38 公里"], correctIndex: 1),
    Question(category: "体育", text: "篮球比赛中，三分线外投篮得几分？", image: nil,
             options: ["1 分", "2 分", "3 分", "4 分"], correctIndex: 2),
    Question(category: "体育", text: "网球大满贯不包括以下哪个赛事？", image: nil,
             options: ["温布尔登", "法国公开赛", "美国公开赛", "世界杯"], correctIndex: 3),
    Question(category: "体育", text: "乒乓球是哪个国家的国球？", image: nil,
             options: ["日本", "韩国", "中国", "德国"], correctIndex: 2),
]

/// 按分类筛选题目，"随机"则从全库随机抽取 10 题
func questions(for category: QuizCategory) -> [Question] {
    if category == .random {
        return Array(allQuestions.shuffled().prefix(10))
    }
    return allQuestions.filter { $0.category == category.rawValue }.shuffled()
}

// MARK: - ViewModel

class QuizViewModel: ObservableObject {
    let questions: [Question]

    @Published var currentIndex: Int = 0
    @Published var selectedIndex: Int? = nil
    @Published var score: Int = 0
    @Published var isFinished: Bool = false

    /// 记录每题用户的选择，key 为题目序号
    private(set) var userAnswers: [Int: Int] = [:]

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
        if index == current.correctIndex { score += 1 }
    }

    func next() {
        if isLastQuestion {
            isFinished = true
        } else {
            currentIndex += 1
            selectedIndex = nil
        }
    }

    func restart() {
        currentIndex = 0
        selectedIndex = nil
        score = 0
        isFinished = false
        userAnswers = [:]
    }

    func optionState(_ index: Int) -> OptionState {
        guard let selected = selectedIndex else { return .normal }
        if index == current.correctIndex { return .correct }
        if index == selected { return .wrong }
        return .dimmed
    }

    /// 指定题目的选项状态（用于答题卡详情回顾）
    func optionState(questionIndex qi: Int, optionIndex oi: Int) -> OptionState {
        let q = questions[qi]
        guard let selected = userAnswers[qi] else { return .normal }
        if oi == q.correctIndex { return .correct }
        if oi == selected { return .wrong }
        return .dimmed
    }

    /// 指定题目是否答对
    func isCorrect(at index: Int) -> Bool {
        userAnswers[index] == questions[index].correctIndex
    }
}

enum OptionState {
    case normal, correct, wrong, dimmed
}

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

// MARK: - 主视图（导航根）

struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 答题容器视图（由导航推入）

struct QuizContainerView: View {
    let category: QuizCategory
    @StateObject private var vm: QuizViewModel

    init(category: QuizCategory) {
        self.category = category
        _vm = StateObject(wrappedValue: QuizViewModel(questions: questions(for: category)))
    }

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            if vm.isFinished {
                ResultView(vm: vm, category: category)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity))
            } else {
                QuizView(vm: vm)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.isFinished)
        .navigationBarBackButtonHidden(vm.isFinished ? true : false)
    }
}

struct QuizView: View {
    @ObservedObject var vm: QuizViewModel

    var body: some View {
        VStack(spacing: 0) {

            // 顶部进度区
            VStack(spacing: 8) {
                HStack {
                    Text("第 \(vm.currentIndex + 1) 题 / 共 \(vm.questions.count) 题")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("得分 \(vm.score)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.quizPurpleLight)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.quizCard)
                        .clipShape(Capsule())
                }

                ProgressView(value: vm.progress)
                    .tint(Color.quizPurple)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)

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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    vm.select(i)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) { vm.next() }
            }) {
                Text(vm.isLastQuestion ? "查看结果" : "下一题")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(vm.isAnswered ? Color.quizPurple : Color.quizCard)
                    .cornerRadius(14)
                    .animation(.easeInOut(duration: 0.2), value: vm.isAnswered)
            }
            .disabled(!vm.isAnswered)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.quizBg.opacity(0.95))
        }
    }
}

// MARK: - 题目卡片（支持图片）

struct QuestionCard: View {
    let question: Question

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text(question.category)
                .font(.system(size: 12))
                .foregroundColor(Color.quizPurpleLight)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.quizPurple.opacity(0.25))
                .clipShape(Capsule())

            Text(question.text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // 可选图片区域
            if let img = question.image {
                QuestionImageView(image: img)
            }

            Text("选择一个正确答案")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.quizCard)
        .cornerRadius(16)
    }
}

// MARK: - 题目图片视图

struct QuestionImageView: View {
    let image: QuestionImage
    @State private var isExpanded = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            imageContent
                .onTapGesture { isExpanded = true }

            // 放大提示角标
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.85))
                .padding(6)
                .background(Color.black.opacity(0.45))
                .cornerRadius(6)
                .padding(8)
        }
        .fullScreenCover(isPresented: $isExpanded) {
            ImageExpandedView(image: image, isPresented: $isExpanded)
        }
    }

    @ViewBuilder
    var imageContent: some View {
        switch image {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .cornerRadius(10)

        case .url(let urlString):
            AsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.quizBorder.opacity(0.4))
                        ProgressView().tint(Color.quizPurpleLight)
                    }
                    .frame(height: 180)

                case .success(let img):
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(10)

                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.quizBorder.opacity(0.4))
                        VStack(spacing: 6) {
                            Image(systemName: "photo.slash")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("图片加载失败")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 180)

                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - 全屏图片查看

struct ImageExpandedView: View {
    let image: QuestionImage
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                switch image {
                case .asset(let name):
                    Image(name)
                        .resizable()
                        .scaledToFit()
                case .url(let urlString):
                    AsyncImage(url: URL(string: urlString)) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFit()
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                }
            }
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { scale = max(1.0, $0) }
                    .onEnded { _ in
                        withAnimation(.spring()) { scale = 1.0 }
                    }
            )

            VStack {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
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
                Circle()
                    .fill(badgeBg)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(badgeFg)
                    )

                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(textColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if state == .correct {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.quizGreen)
                        .font(.system(size: 20))
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.quizRed)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(bgColor)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: state == .normal ? 0.5 : 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isAnswered)
        .scaleEffect(state == .correct || state == .wrong ? 1.02 : 1.0)
    }

    var bgColor: Color {
        switch state {
        case .correct: return Color(red: 0.13, green: 0.26, blue: 0.17)
        case .wrong:   return Color(red: 0.26, green: 0.13, blue: 0.13)
        case .dimmed:  return Color.quizCard.opacity(0.6)
        case .normal:  return Color.quizCard
        }
    }

    var borderColor: Color {
        switch state {
        case .correct: return Color.quizGreen
        case .wrong:   return Color.quizRed
        default:       return Color.quizBorder
        }
    }

    var textColor: Color { state == .dimmed ? .secondary : .white }

    var badgeBg: Color {
        switch state {
        case .correct: return Color.quizGreen.opacity(0.3)
        case .wrong:   return Color.quizRed.opacity(0.3)
        default:       return Color.quizBorder
        }
    }

    var badgeFg: Color {
        switch state {
        case .correct: return Color.quizGreen
        case .wrong:   return Color.quizRed
        default:       return .secondary
        }
    }
}

// MARK: - 结果视图

struct ResultView: View {
    @ObservedObject var vm: QuizViewModel
    let category: QuizCategory
    @State private var showAnswerSheet = false
    @Environment(\.dismiss) private var dismiss

    var percentage: Int {
        Int(Double(vm.score) / Double(vm.questions.count) * 100)
    }

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

            ZStack {
                Circle()
                    .stroke(Color.quizBorder, lineWidth: 8)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: CGFloat(percentage) / 100)
                    .stroke(Color.quizPurple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: percentage)

                VStack(spacing: 4) {
                    Text("\(vm.score)/\(vm.questions.count)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(percentage)%")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text(grade.label)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(grade.color)
                Text("你答对了 \(vm.score) 道题，共 \(vm.questions.count) 题")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                StatCard(value: "\(vm.score)", label: "答对", color: Color.quizGreen)
                StatCard(value: "\(vm.questions.count - vm.score)", label: "答错", color: Color.quizRed)
                StatCard(value: "\(percentage)%", label: "正确率", color: Color.quizPurpleLight)
            }
            .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 12) {
                // 答题卡按钮
                Button(action: { showAnswerSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 16))
                        Text("答题卡")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(Color.quizPurpleLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.quizPurple.opacity(0.2))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.quizPurple.opacity(0.5), lineWidth: 1)
                    )
                }

                // 再来一次按钮
                Button(action: {
                    dismiss()
                }) {
                    Text("再来一次")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.quizPurple)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showAnswerSheet) {
            AnswerSheetView(vm: vm)
        }
    }
}

// MARK: - 答题卡视图

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

                        // 图例说明
                        HStack(spacing: 20) {
                            LegendItem(color: Color.quizGreen, label: "答对")
                            LegendItem(color: Color.quizRed,   label: "答错")
                            Spacer()
                            Text("\(vm.score) / \(vm.questions.count) 题正确")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // 题目格子
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<vm.questions.count, id: \.self) { i in
                                Button(action: { selectedQuestionIndex = i }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(vm.isCorrect(at: i)
                                                  ? Color.quizGreen.opacity(0.2)
                                                  : Color.quizRed.opacity(0.2))
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(vm.isCorrect(at: i)
                                                    ? Color.quizGreen
                                                    : Color.quizRed,
                                                    lineWidth: 1.2)

                                        VStack(spacing: 4) {
                                            Text("\(i + 1)")
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(.white)
                                            Image(systemName: vm.isCorrect(at: i)
                                                  ? "checkmark" : "xmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(vm.isCorrect(at: i)
                                                                 ? Color.quizGreen
                                                                 : Color.quizRed)
                                        }
                                    }
                                    .frame(height: 60)
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
                    Button("完成") { dismiss() }
                        .foregroundColor(Color.quizPurpleLight)
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

/// 用于 sheet(item:) 的轻量包装
struct AnswerSheetIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

/// 图例说明小组件
struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.25))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: 1))
                .frame(width: 18, height: 18)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 题目详情回顾视图

struct QuestionReviewView: View {
    @ObservedObject var vm: QuizViewModel
    let questionIndex: Int
    @Environment(\.dismiss) private var dismiss

    var question: Question { vm.questions[questionIndex] }
    var userAnswer: Int?   { vm.userAnswers[questionIndex] }
    var isCorrect: Bool    { vm.isCorrect(at: questionIndex) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.quizBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // 结果横幅
                        HStack(spacing: 10) {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(isCorrect ? Color.quizGreen : Color.quizRed)
                            Text(isCorrect ? "回答正确" : "回答错误")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isCorrect ? Color.quizGreen : Color.quizRed)
                            Spacer()
                            Text("第 \(questionIndex + 1) 题")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(
                            isCorrect
                            ? Color.quizGreen.opacity(0.12)
                            : Color.quizRed.opacity(0.12)
                        )
                        .cornerRadius(14)

                        // 题目卡片（只读）
                        QuestionCard(question: question)

                        // 选项列表（只读回顾，所有选项都显示状态）
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

                        // 正确答案说明（答错时额外提示）
                        if !isCorrect {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 14))
                                Text("正确答案：\(["A","B","C","D"][question.correctIndex])  \(question.options[question.correctIndex])")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.85))
                                Spacer()
                            }
                            .padding(14)
                            .background(Color(red: 0.20, green: 0.18, blue: 0.10))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("题目详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(Color.quizPurpleLight)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
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

// MARK: - 预览

#Preview {
    ContentView()
}
