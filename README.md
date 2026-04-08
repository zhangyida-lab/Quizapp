# QuizApp

一款基于 SwiftUI 开发的 iOS 趣味答题应用，支持题库管理、错题本、每日推荐、试卷生成等功能。

---

## 功能概览

| 功能 | 说明 |
|------|------|
| 题库管理 | 支持 JSON 导入/导出，内置 36 道题目 |
| 分类答题 | 按科目分类刷题，支持随机混合 |
| 错题本 | 自动记录错题，SM-2 算法智能调度复习 |
| 每日推荐 | 到期错题优先 + 随机新题，每日自动更新 |
| 拍照录题 | Vision OCR 识别题目文字，离线可用 |
| 试卷生成 | 自选科目/难度/题数/总分，支持考试与练习两种模式 |
| 空白试卷导出 | 生成适合打印的空白 PDF 试卷，含答案汇总页 |
| 历史试卷 | 保存每次作答记录，支持重新作答，成绩可导出 PDF |

---

## 技术栈

- **语言**：Swift 5
- **UI 框架**：SwiftUI（iOS 18.2+）
- **开发工具**：Xcode 16.2
- **持久化**：UserDefaults + JSONEncoder/Decoder
- **OCR**：Apple Vision framework（离线，支持中英文）
- **PDF**：UIGraphicsPDFRenderer 生成 / QLPreviewController 预览
- **图片选取**：PhotosUI.PhotosPicker

---

## 项目架构

### 整体模式：单向数据流

```
QuizStore（单一数据源）
     │
     ├── @Published var questionBanks
     ├── @Published var wrongRecords
     ├── @Published var examPapers
     └── @Published var dailyQuestions
           │
           ▼
    所有 View 通过 @EnvironmentObject 读取和修改
```

`QuizStore` 是整个应用的中央数据仓库，在 App 入口以 `@StateObject` 创建，通过 `.environmentObject()` 注入所有子视图，任意层级的视图都可以通过 `@EnvironmentObject` 访问，无需层层传参。

### 文件结构

```
swiftUI Practice/
├── swiftUI_PracticeApp.swift     # @main 入口，注入 QuizStore
├── Quizapp.swift                 # 全局色彩主题 + 通用答题组件（QuizViewModel、OptionButton 等）
├── Homeview.swift                # 首页（分类卡片、今日推荐横幅、FlowLayout）
├── Models/
│   ├── Question.swift            # 题目、题库、JSON 导入格式定义
│   ├── WrongRecord.swift         # 错题记录 + SM-2 间隔重复算法
│   ├── ExamConfig.swift          # 试卷配置（科目、难度、计分模式、答题模式）
│   └── ExamPaper.swift           # 试卷快照 + 历次作答记录
├── Store/
│   ├── QuizStore.swift           # 中央数据仓库、持久化、业务逻辑
│   └── BuiltInQuestions.swift    # 内置题库（36 题，6 个分类）
└── Views/
    ├── MainTabView.swift          # 5 个 Tab 导航
    ├── DailyReviewView.swift      # 今日推荐
    ├── WrongBookView.swift        # 错题本
    ├── LibraryView.swift          # 题库管理
    ├── PhotoCaptureView.swift     # 拍照录题 + OCR
    ├── ExamConfigView.swift       # 试卷配置页
    ├── ExamContainerView.swift    # 答题界面 + 成绩结果 + PDF 生成
    └── ExamHistoryView.swift      # 历史试卷列表与详情
```

**分层原则：**
- `Models/` — 纯数据结构，零 UI 依赖
- `Store/` — 业务逻辑、持久化、计算属性
- `Views/` — 纯展示与用户交互，不直接操作数据

---

## 架构与编程技巧详解

### 1. `@ViewBuilder` + 计算属性拆分大视图

把每个 UI 区块拆成独立的计算属性，`body` 保持清晰：

```swift
var body: some View {
    ScrollView {
        VStack {
            headerSection
            statsRow
            dueSectionIfNeeded
            questionListSection
        }
    }
}

@ViewBuilder
var dueSectionIfNeeded: some View {
    if !store.dueQuestions.isEmpty {
        VStack { ... }
    }
}
```

### 2. 自定义 `Layout` 协议实现标签云

iOS 16 新增能力，比 `GeometryReader` 更优雅：

```swift
struct FlowLayout: Layout {
    func sizeThatFits(proposal:, subviews:, cache:) -> CGSize { ... }
    func placeSubviews(in bounds:, proposal:, subviews:, cache:) { ... }
}
```

两个方法：一个告诉父视图"我需要多大"，一个决定"子视图放在哪"。

### 3. 自定义 `Binding` 保持数据单向流

```swift
Toggle("", isOn: Binding(
    get: { bank.isEnabled },
    set: { _ in onToggle() }   // 只触发回调，不直接存值
))
```

避免把 `let` 改成 `@State`，保持数据流的单向性。

### 4. `UIViewControllerRepresentable` 桥接 UIKit

SwiftUI 没有内置 PDF 预览控件，通过此协议包装 `QLPreviewController`：

```swift
struct PDFPreviewView: UIViewControllerRepresentable {
    func makeUIViewController(context:) -> UINavigationController { ... }
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
}
```

**Coordinator 模式**负责实现 UIKit 的 delegate/dataSource 协议，是 SwiftUI 与 UIKit 互操作的标准写法。

### 5. 现代并发：`async/await` + `MainActor`

```swift
func loadImage(from item: PhotosPickerItem?) async {
    if let data = try? await item.loadTransferable(type: Data.self) {
        await MainActor.run { selectedImage = UIImage(data: data) }
    }
}
```

`MainActor.run` 保证 UI 更新在主线程执行，比 `DispatchQueue.main.async` 类型更安全。

### 6. SM-2 间隔重复算法

经典记忆科学算法，答对间隔指数增长，答错从头来：

```swift
mutating func update(isCorrect: Bool) {
    if isCorrect {
        correctStreak += 1
        intervalDays = correctStreak == 1 ? 1
                     : correctStreak == 2 ? 3
                     : Int(Double(intervalDays) * easeFactor)
        easeFactor = max(1.3, easeFactor + 0.1)
    } else {
        correctStreak = 0
        intervalDays  = 1
        easeFactor    = max(1.3, easeFactor - 0.2)
        wrongCount   += 1
    }
    nextReviewDate = Calendar.current.date(byAdding: .day, value: intervalDays, to: Date())!
}
```

`easeFactor` 是个人化参数，答得越准确，复习间隔增长越快。

### 7. 安全下标扩展

```swift
private extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
```

用 `array[safe: i]` 替代 `array[i]`，越界时返回 `nil` 而不是崩溃。

### 8. 试卷快照设计（数据解耦）

`ExamPaper` 存储题目的完整副本而非 ID 引用：

```swift
struct ExamPaper: Codable {
    var questions: [Question]   // 快照，不是引用
    var questionScores: [Int]
    var attempts: [ExamAttempt]
}
```

即使题库中的题目被删改，历史试卷依然能完整回放，体现了"事件溯源"的设计思想。

---

## JSON 题库格式

```json
{
  "version": "1.0",
  "name": "题库名称",
  "questions": [
    {
      "category": "分类名",
      "text": "题目内容",
      "options": ["选项A", "选项B", "选项C", "选项D"],
      "correctIndex": 0,
      "difficulty": 3,
      "explanation": "解析（可选）"
    }
  ]
}
```

`difficulty` 取值 1–5，`explanation` 和 `id` 字段均可省略。

---

## 后续可探索的方向

| 方向 | 说明 |
|------|------|
| SwiftData | 用 iOS 17 新框架替换 UserDefaults 持久化 |
| async/await 全量迁移 | 把剩余的 DispatchQueue 换成现代并发写法 |
| AI 解析接入 | 为题目解析字段对接大模型 API |
| Unit Test | 测试 QuizStore 业务逻辑和 SM-2 算法 |
| @Observable | iOS 17 新响应式宏，替换 ObservableObject |
