# Lexora

一款基于 SwiftUI 开发的 iOS 学习应用，集答题刷题与英语词汇记忆于一体，配备 SM-2 间隔重复算法、iOS Widget、Siri 快捷指令和可配置学习算法。

---

## 功能概览

### 刷题模块

| 功能 | 说明 |
|------|------|
| 分类答题 | 按科目分类刷题，支持随机混合练习 |
| 错题本 | 自动记录错题，SM-2 算法智能调度复习时间 |
| 每日推荐 | 到期错题优先 + 错误率加权随机补充，每日自动更新 |
| 题库管理 | JSON 导入/导出，内置 36 道题，支持拍照 OCR 录题 |
| 试卷生成 | 自选科目/难度/题数/总分，支持考试与练习两种模式 |
| 历史试卷 | 保存每次作答记录，支持重新作答，成绩可导出 PDF |

### 词汇模块

| 功能 | 说明 |
|------|------|
| 内置词库 | 11 个词库（初中/高中/CET-4 精选&完整/CET-6 精选&完整/考研/托福/SAT/商务/技术），按需启用 |
| 闪卡复习 | SM-2 间隔重复调度，翻卡查看释义，支持 TTS 发音 |
| 词义选择题 | 四选一快速练习模式 |
| 不认识单词本 | 自动收录闪卡中标为「不认识」的单词，专项攻克难词 |
| 每日词汇推荐 | 按新词比例配置，自动混合新词与待复习旧词 |
| iOS Widget | 主屏幕小组件显示今日词汇数据，点击跳转 App |
| Siri 快捷指令 | 说「Add word in Lexora」快速收录生词 |
| 截图识词 | Vision OCR 批量识别截图中的单词并添加 |
| QR 导入 | 扫码导入词库 JSON |

### 通用

| 功能 | 说明 |
|------|------|
| 算法设置 | 可配置每日推荐题数、每日背词数、SM-2 参数等 |
| PDF 导出 | 答题结果报告、考试成绩单、空白试卷 |
| 推荐 Tab | 一页切换今日刷题推荐和今日背词推荐 |

---

## 技术栈

- **语言**：Swift 5
- **UI 框架**：SwiftUI（iOS 18.2+）
- **开发工具**：Xcode 16.2
- **持久化**：UserDefaults + JSONEncoder/Decoder（含 App Group 跨进程共享）
- **OCR**：Apple Vision framework（离线，支持中英文）
- **PDF**：UIGraphicsPDFRenderer 生成 / QLPreviewController 预览
- **Widget**：WidgetKit（4 种尺寸，30 分钟刷新）
- **Siri**：App Intents framework
- **图片选取**：PhotosUI.PhotosPicker

---

## 项目架构

### 整体模式：多 Store + 单向数据流

```
QuizStore              VocabularyStore         AlgorithmSettingsStore
（答题数据源）           （词汇数据源）              （算法配置）
     │                      │                         │
     └──────────────────────┴─────────────────────────┘
                            │
                @EnvironmentObject 注入所有视图
```

三个 `ObservableObject` 在 `LexoraApp` 入口以 `@StateObject` 创建，通过 `.environmentObject()` 注入全部子视图。`AlgorithmSettingsStore` 同时提供静态方法 `loadConfig()`，供 Store 层读取配置而无需 UI 注入。

### Tab 结构

| Tab | 图标 | 内容 |
|-----|------|------|
| 推荐 | calendar.badge.clock | 今日刷题/背词推荐（顶部切换） |
| 刷题 | bolt.fill | 分类答题、错题本、题库管理（工具栏入口） |
| 背词 | brain.head.profile | 词库列表、闪卡、选词练习、不认识单词本 |
| 设置 | gearshape.fill | 算法设置、使用帮助、关于 Lexora、隐私政策 |

### 文件结构

```
swiftUI Practice/
├── swiftUI_PracticeApp.swift         # @main 入口，注入三个 Store
├── Quizapp.swift                     # 全局色彩主题 + 通用答题组件（QuizViewModel、OptionButton 等）
├── Homeview.swift                    # 刷题 Tab 主页 + HelpView（使用帮助）
├── LexoraIconView.swift              # App 图标设计（ImageRenderer 导出）
├── Models/
│   ├── Question.swift                # 题目、题库、JSON 导入格式
│   ├── WrongRecord.swift             # 错题记录 + SM-2 算法（可配置参数）
│   ├── ExamConfig.swift              # 试卷配置（科目、难度、计分模式）
│   ├── ExamPaper.swift               # 试卷快照 + 历次作答记录
│   └── Word.swift                    # 单词、词库、SM-2 学习记录
├── Store/
│   ├── QuizStore.swift               # 答题数据仓库、每日推荐、加权随机补充
│   ├── VocabularyStore.swift         # 词汇数据仓库、TTS、enrichment、每日单词
│   ├── AlgorithmSettings.swift       # 算法配置结构体 + AlgorithmSettingsStore
│   ├── BuiltInQuestions.swift        # 内置题库（36 题）
│   ├── BuiltInWordBooks.swift        # 内置词库目录（11 个，懒加载）
│   └── VocabSharedHelper.swift       # Widget/Siri Extension 共享层（App Group）
├── WordBooks/                        # 11 个内置词库 JSON（Bundle 资源）
├── VocabAppIntents.swift             # Siri App Intents（AddWord、TodayWords）
└── Views/
    ├── MainTabView.swift             # 4 个 Tab 导航
    ├── DailyReviewView.swift         # 推荐 Tab（刷题/背词双面板）
    ├── SettingsView.swift            # 设置 Tab（算法、帮助、关于、隐私）
    ├── AlgorithmSettingsView.swift   # 算法参数配置表单
    ├── WrongBookView.swift           # 错题本
    ├── LibraryView.swift             # 题库管理（导入/导出/生成试卷）
    ├── PhotoCaptureView.swift        # 拍照录题 + OCR
    ├── ExamConfigView.swift          # 试卷配置页
    ├── ExamContainerView.swift       # 考试界面 + 成绩结果 + PDF 生成
    ├── ExamHistoryView.swift         # 历史试卷列表与详情
    └── Vocabulary/
        ├── VocabularyHomeView.swift  # 背词 Tab 主页（词库列表、不认识单词横幅）
        ├── FlashCardView.swift       # 闪卡练习
        ├── WordChoiceView.swift      # 词义选择练习
        ├── UnknownWordsView.swift    # 不认识单词本（专项闪卡练习）
        ├── WordNotebookView.swift    # 单词本（按掌握程度筛选）
        ├── WordAddViews.swift        # 手动添加 + 截图 OCR 批量添加
        └── VocabQRImportView.swift   # QR 扫码导入词库

VocabWidget/
└── VocabWidget.swift                # WidgetKit 小组件（4 种尺寸）
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

### 6. SM-2 间隔重复算法（可配置参数）

经典记忆科学算法，答对间隔指数增长，答错重置间隔：

```swift
mutating func update(isCorrect: Bool,
                     wrongResetDays: Int = 1,
                     minEaseFactor: Double = 1.3,
                     easePenalty: Double = 0.2) {
    if isCorrect {
        correctStreak += 1
        intervalDays = correctStreak == 1 ? 1
                     : correctStreak == 2 ? 3
                     : Int(Double(intervalDays) * easeFactor)
        easeFactor = max(minEaseFactor, easeFactor + 0.1)
    } else {
        correctStreak = 0
        intervalDays  = wrongResetDays
        easeFactor    = max(minEaseFactor, easeFactor - easePenalty)
        wrongCount   += 1
    }
    nextReviewDate = Calendar.current.date(byAdding: .day, value: intervalDays, to: Date())!
}
```

`easeFactor` 是个人化参数，答得越准确，复习间隔增长越快。算法参数可在「设置 → 算法设置」中调整。

### 7. navigationDestination 崩溃防护

`navigationDestination` 的 closure 会在 Store 数据变更时重新执行，如果直接使用计算属性作为数组来源会导致 index-out-of-range 崩溃。正确做法是先将数组快照到 `@State`：

```swift
// 错误：store 更新时 closure 重新执行，数组缩短，currentIndex 越界
.navigationDestination(isPresented: $showFlashCard) {
    FlashCardView(words: vocabStore.unknownWords.shuffled())
}

// 正确：进入前先快照
Button {
    flashCardWords = words.shuffled()  // 快照到 @State
    showFlashCard = true
} label: { ... }
.navigationDestination(isPresented: $showFlashCard) {
    FlashCardView(words: flashCardWords)  // 使用稳定快照
}
```

### 8. 跨进程共享：App Group + UserDefaults

Widget Extension 和 Siri App Intent 需要读写主 App 数据，SwiftData 不支持跨 target，改用 `UserDefaults(suiteName:)` 配合 App Group：

```swift
// VocabSharedHelper.swift
extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.com.acspace.Lexora")!
}

// 主 App 写入
UserDefaults.shared.set(encoded, forKey: "vocab_total_count_v1")

// Widget / Siri Intent 读取
let count = UserDefaults.shared.integer(forKey: "vocab_total_count_v1")
```

### 9. 试卷快照设计（数据解耦）

`ExamPaper` 存储题目的完整副本而非 ID 引用：

```swift
struct ExamPaper: Codable {
    var questions: [Question]   // 快照，不是引用
    var questionScores: [Int]
    var attempts: [ExamAttempt]
}
```

即使题库中的题目被删改，历史试卷依然能完整回放，体现了「事件溯源」的设计思想。

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

## 真机测试

### 前置条件

- Mac + USB 连接 iPhone（或同一 Wi-Fi 下无线连接）
- Xcode 已登录 Apple ID（免费账号即可）

### 第一步：选择真机并 Build

1. 打开 `swiftUI Practice.xcodeproj`
2. Xcode 顶部工具栏 → 选择你的 iPhone
3. 首次连接需在 iPhone 上点击 **「信任此电脑」**
4. 确认 Scheme 是 **Lexora**（主 App）
5. `Cmd+R` 构建并安装到真机

> 首次在真机运行，iPhone 会提示「未受信任的开发者」：  
> **设置 → 通用 → VPN 与设备管理 → 找到你的 Apple ID → 信任**

### 第二步：测试背词 Tab

App 启动后切换到第 3 个 Tab（背词）：

| 测试项 | 预期结果 |
|--------|----------|
| 进入背词 Tab | 显示内置词库列表，默认全部未启用 |
| 点击「启用」任意词库 | 异步加载完成后可进入复习 |
| 闪卡复习 | 左右滑动翻页，点击卡片翻转看释义，发音按钮可朗读 |
| 选词练习 | 四选一，答完显示正误 |
| 不认识单词本 | 闪卡中标「不认识」后，这里出现对应单词入口 |

### 第三步：测试 iOS Widget

1. 回到 iPhone 主屏幕，**长按空白区域**进入编辑模式
2. 点击左上角 **`+`** → 搜索 **Lexora**
3. 选择尺寸（小/中/大/超大），添加小组件

| 测试项 | 预期结果 |
|--------|----------|
| Widget 显示 | 显示今日词汇和总词数 |
| 点击 Widget | 自动跳转到 App 背词 Tab |

> **Widget 不显示？** 确认已启用至少一个词库，Widget 需要有数据才会正常渲染。

### 第四步：测试 Siri 快捷指令

1. 打开 App 至少一次（激活 App Intent 注册）
2. 呼出 Siri，说：**「Add word in Lexora」**
3. Siri 会追问要添加哪个单词，回答后自动保存

> **Siri 没响应？** 在 **设置 → Siri 与搜索** 里搜索 App 名，确认快捷指令已启用。

### 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| Build 失败：App Groups 签名错误 | 免费账号不支持特定 capability | Xcode → Signing & Capabilities → 开启 Automatically manage signing |
| Widget 装不上 | VocabWidget Extension 未打包进 App | 确认 Scheme 是主 App（它会连同 Extension 一起打包） |
| 词库启用后 Widget 不更新 | Widget 有 30 分钟缓存 | 正常现象；或删除 Widget 重新添加 |
| Siri 无法识别指令 | App 没在真机上运行过 | 先 `Cmd+R` 跑一次 App 再测 Siri |

---

## App Store 准备状态

| 项目 | 状态 |
|------|------|
| Privacy Manifest（PrivacyInfo.xcprivacy） | 完成，主 App + Widget 各一份 |
| 隐私政策页面 | 完成，托管于 GitHub Pages |
| 相机/相册权限说明（Info.plist） | 待补充 NSCameraUsageDescription / NSPhotoLibraryUsageDescription |
| App Store Connect 截图 | 待完成（至少 iPhone 6.5"） |
| App 图标 1024×1024 | 已设计（LexoraIconView.swift） |

隐私政策地址：`https://zhangyida-lab.github.io/lexora-privacy/`

---

## 后续可探索的方向

| 方向 | 说明 |
|------|------|
| 单词自动补全增强 | 接入在线词典 API，自动填充释义、音标、例句 |
| AI 解析接入 | 为题目解析字段对接大模型 API |
| Unit Test | 测试 QuizStore / VocabularyStore 业务逻辑和 SM-2 算法 |
| @Observable | iOS 17 新响应式宏，替换 ObservableObject |
| CloudKit 同步 | 多设备学习数据同步 |
