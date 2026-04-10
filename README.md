# Lexora

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

## 词汇模块（feature/vocabulary-learning）

> 开发中功能，独立分支，主分支暂无此功能。

| 功能 | 说明 |
|------|------|
| 词汇 Tab | 11 个内置词库（初中/高中/CET-4/6/考研/托福/SAT 等），可按需启用 |
| 闪卡复习 | SM-2 间隔重复算法调度，支持发音 |
| 词义选择题 | 四选一快速练习模式 |
| 单词本 | 按掌握程度筛选（待复习 / 学习中 / 已掌握） |
| iOS Widget | 主屏幕小组件显示今日词汇，点击跳转 App |
| Siri 快捷指令 | 说"添加生词 [单词]"快速收录 |
| QR 导入 | 扫码导入词库 JSON |

**架构说明：** 使用 `UserDefaults + JSONEncoder` + `App Group` 实现主 App 与 Widget Extension 跨进程共享数据，不使用 SwiftData（SwiftData 不支持跨 target 共享）。

---

## 真机测试：词汇快速记词功能

### 前置条件

- Mac + USB 连接 iPhone（或同一 Wi-Fi 下无线连接）
- Xcode 已登录 Apple ID（免费账号即可）
- 当前分支：`feature/vocabulary-learning`

---

### 第一步：选择真机并 Build

1. 打开 `swiftUI Practice.xcodeproj`
2. Xcode 顶部工具栏，点击 Simulator 下拉菜单 → 选择你的 iPhone
3. 首次连接需在 iPhone 上点击 **"信任此电脑"**
4. 确认 Scheme 是 **Lexora**（主 App，不是 VocabWidget）
5. `Cmd+R` 构建并安装到真机

> 首次在真机运行，iPhone 会提示"未受信任的开发者"：  
> **设置 → 通用 → VPN 与设备管理 → 找到你的 Apple ID → 信任**

---

### 第二步：测试词汇 Tab 基础功能

App 启动后切换到第 4 个 Tab（词汇图标）：

| 测试项 | 预期结果 |
|--------|----------|
| 进入词汇 Tab | 显示内置词库列表，默认全部未启用 |
| 点击"启用"任意词库 | 异步加载，显示 loading，完成后可进入复习 |
| 闪卡复习 | 左右滑动翻页，点击卡片翻转看释义，发音按钮可朗读 |
| 词义选择题 | 四选一，答完显示正误 |
| 单词本 | 显示已学单词，按掌握程度筛选 |

---

### 第三步：测试 iOS Widget

1. 回到 iPhone 主屏幕，**长按空白区域**进入编辑模式
2. 点击左上角 **`+`**
3. 搜索 **"swiftUI Practice"** 或 **"词汇"**
4. 选择尺寸（小/中/大/超大），点击 **"添加小组件"**
5. 按 Done 退出编辑模式

| 测试项 | 预期结果 |
|--------|----------|
| Widget 显示 | 显示今日词汇和总词数 |
| 30 分钟后 | Widget 自动刷新（或长按 Widget → 编辑 → 强制刷新） |
| 点击 Widget | 自动跳转到 App 词汇 Tab |

> **Widget 不显示？** 确认已启用至少一个词库，Widget 需要有数据才会正常渲染。

---

### 第四步：测试 Siri 快捷指令

1. 打开 App 至少一次（激活 App Intent 注册）
2. 呼出 Siri，说：**"添加生词 hello"**
3. 或说：**"今日词汇"**

| 指令 | 预期结果 |
|------|----------|
| 添加生词 [单词] | Siri 回复确认，单词加入"我的生词本" |
| 今日词汇 | Siri 展示今日学习词汇列表 |

> **Siri 没响应？** 在 **设置 → Siri 与搜索** 里搜索 App 名，确认快捷指令已启用。

---

### 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| Build 失败：App Groups 签名错误 | 免费账号不支持特定 capability | 在 Xcode → Signing & Capabilities 确认 Team 已选择，开启 Automatically manage signing |
| Widget 装不上 | VocabWidget Extension 未 build 进 App | 确认 Scheme 是主 App（它会连同 Extension 一起打包） |
| 词库启用后 Widget 不更新 | Widget 有 30 分钟缓存 | 正常现象；或删除 Widget 重新添加 |
| Siri 无法识别指令 | App 没在真机上运行过 | 先 `Cmd+R` 跑一次 App 再测 Siri |

---

## 后续可探索的方向

| 方向 | 说明 |
|------|------|
| SwiftData | 用 iOS 17 新框架替换 UserDefaults 持久化 |
| async/await 全量迁移 | 把剩余的 DispatchQueue 换成现代并发写法 |
| AI 解析接入 | 为题目解析字段对接大模型 API |
| Unit Test | 测试 QuizStore 业务逻辑和 SM-2 算法 |
| @Observable | iOS 17 新响应式宏，替换 ObservableObject |
