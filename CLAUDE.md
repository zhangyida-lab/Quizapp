# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS quiz app built with SwiftUI, targeting iOS 18.2, Xcode 16.2, Swift 5. The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16 feature), so **all Swift files in subfolders are automatically included** — no need to add files to `project.pbxproj` manually.

## Build & Run

Open `swiftUI Practice.xcodeproj` in Xcode. Build/run with `Cmd+R`. There are no test targets, no lint scripts, and no CLI build commands. All development happens through Xcode.

## Architecture

**Single source of truth:** `QuizStore` (`Store/QuizStore.swift`) is an `ObservableObject` instantiated once in `swiftUI_PracticeApp.swift` and injected as `.environmentObject(store)` into all views. All views read from and write to `QuizStore` via `@EnvironmentObject private var store: QuizStore`.

**Persistence:** `UserDefaults` + `JSONEncoder/Decoder` with `.iso8601` date strategy. Storage keys:
- `quiz_banks_v2` — `[QuestionBank]`
- `quiz_wrong_records_v2` — `[WrongRecord]`
- `quiz_exam_papers_v1` — `[ExamPaper]`
- `quiz_daily_questions_v2` / `quiz_daily_date_v2` — daily cache

**Navigation:** `MainTabView` (4 tabs) wraps each tab in its own `NavigationStack`. Deep navigation uses `NavigationLink` and `.navigationDestination`.

**Quiz flow:**
1. User picks category (HomeView) or configures exam (ExamConfigView → LibraryView tab)
2. `QuizViewModel` manages per-session state (currentIndex, selectedIndex, userAnswers, score)
3. `QuizContainerView` (category/wrong-book quizzes) or `ExamContainerView` (generated exam papers) renders questions using shared UI components from `Quizapp.swift`
4. `vm.onAnswer` callback reports each answer to `QuizStore.recordAnswer()` for SM-2 tracking

## Key Files

| File | Purpose |
|------|---------|
| `Quizapp.swift` | Color theme (`Color.quiz*`), `QuizViewModel`, `OptionState` enum, all shared quiz UI (`QuestionCard`, `OptionButton`, `ResultView`, `QuizPDFGenerator`), `PDFPreviewView` |
| `Store/QuizStore.swift` | Central store: `allQuestions`, `categories`, `wrongQuestions`, `dueQuestions`, SM-2 scheduling, exam paper CRUD |
| `Models/Question.swift` | `Question`, `QuestionBank`, `QuestionBankImport` (lenient JSON parsing) |
| `Models/WrongRecord.swift` | SM-2 algorithm in `update(isCorrect:)`, `isDue`, `priorityScore` |
| `Models/ExamConfig.swift` | `ExamConfig` (Codable): `ScoreMode` (.uniform/.byDifficulty), `ExamMode` (.practice/.exam), `selectQuestions()`, `scores(for:)` |
| `Models/ExamPaper.swift` | `ExamPaper` (full question snapshot, multiple `ExamAttempt`s), `bestAttempt`, `lastAttempt` |
| `Store/BuiltInQuestions.swift` | 36 built-in questions, fixed UUID `"00000000-0000-0000-0000-000000000001"` |
| `Views/ExamContainerView.swift` | Exam session + `ExamPDFGenerator`（成绩单）+ `BlankExamPDFGenerator`（空白试卷，无装饰线） |
| `Views/ExamHistoryView.swift` | Lists saved `ExamPaper`s, `PaperDetailView` with attempt history and re-take button |
| `Views/LibraryView.swift` | 题库管理，含「生成试卷」「历史试卷」「拍照录题」入口 |
| `Homeview.swift` | 刷题 Tab 主页：分类网格 + 错题本入口 + `HelpView`（使用帮助，设置 Tab 入口） |
| `Views/DailyReviewView.swift` | 推荐 Tab：顶部切换「刷题 / 背词」两个面板，各显示今日推荐列表 |
| `Views/SettingsView.swift` | 设置 Tab：算法设置、使用帮助、关于 Lexora、反馈与联系、隐私与法律 |
| `Views/AlgorithmSettingsView.swift` | 算法参数配置表单（每日题数、每日词数、SM-2 参数、试卷默认值） |
| `Store/AlgorithmSettings.swift` | `AlgorithmConfig` 结构体 + `AlgorithmSettingsStore: ObservableObject`；提供静态 `loadConfig()` 供 Store 层读取 |

## PDF 生成注意事项

两套 PDF 生成器，**必须用 `multiline: true` 才能让文字正确对齐**：
- `QuizPDFGenerator`（`Quizapp.swift`）：普通答题结果报告，`drawText` 函数
- `ExamPDFGenerator` / `BlankExamPDFGenerator`（`ExamContainerView.swift`）：考试成绩单 / 空白试卷，`drawTxt` 函数

不加 `multiline: true` 时：水平对齐（`.center`）不生效，垂直起点计算方式也与多行模式不同，导致题号和题目文字错位。

## Exam Mode Logic

`ExamMode.practice` — `vm.optionState()` returns `.correct`/`.wrong`/`.dimmed` immediately after answering.  
`ExamMode.exam` — `examOptionState()` in `ExamContainerView` returns `.selected` (blue highlight, no reveal) while answering; correct/wrong shown only in result view after submission.

`OptionState` has 5 cases: `.normal`, `.correct`, `.wrong`, `.dimmed`, `.selected`. Styling for all states lives in `OptionButton` inside `Quizapp.swift`.

## Data Flow Patterns

- **Adding a question to store:** `QuizStore.addQuestion(_:)` appends to the first non-built-in bank, or creates "我的题库" if none exists.
- **Exam paper lifecycle:** `ExamContainerView.onAppear` → `store.saveExamPaper()` returns `UUID` → stored in `@State var paperId`. On finish → `store.addAttempt(_:toPaperId:)`.
- **Re-taking a paper:** Pass `existingPaperId` to `ExamContainerView`; it skips `saveExamPaper` and appends a new attempt to the existing paper.
- **Daily recommendations:** `QuizStore.generateDailyRecommendations()` — up to 15 due SM-2 questions + random fill to 20. Cached per calendar day.

## Category System

Categories are **dynamic** — derived at runtime from `QuizStore.allQuestions` grouped by `question.category`. `CategoryInfo` (in `QuizStore.swift`) provides icon, color, and description for known categories (地理/科学/历史/数学/艺术/体育); unknown categories get a hash-stable color.

## JSON Import Format

```json
{
  "version": "1.0",
  "name": "题库名称",
  "questions": [
    {
      "category": "分类名",
      "text": "题目内容",
      "options": ["A", "B", "C", "D"],
      "correctIndex": 0,
      "difficulty": 3,
      "explanation": "解析（可选）"
    }
  ]
}
```

`QuestionBankImport` provides lenient parsing — `id`, `difficulty`, `explanation`, `tags` are all optional.

---

## Vocabulary Module

### 架构概述
词汇模块**不使用 SwiftData**，采用 `UserDefaults + JSONEncoder` + `ObservableObject`，原因是 Widget Extension 和 Siri App Intent 需要跨进程读写，SwiftData 不支持跨 target 共享。

**App Group ID：** `group.com.acspace.Lexora`（已更名，entitlements 已同步）

### 核心文件

| 文件 | 职责 |
|------|------|
| `Models/Word.swift` | `Word`、`WordBook`、`WordRecord`（SM-2）、`WordBookImport`（宽松解析） |
| `Store/VocabularyStore.swift` | 主 ObservableObject，管理词库/记录/TTS/每日单词；含 `reload()`、`updateWord()`、`enrichPendingWords()`、`applyEnrichment(from:)` |
| `Store/BuiltInWordBooks.swift` | 11 个内置词库目录（指向 Bundle JSON），懒加载 |
| `Store/VocabSharedHelper.swift` | 轻量静态层，供 Widget/Siri Extension 使用，含 `UserDefaults.shared` 定义（suite: `group.com.acspace.Lexora`） |
| `VocabAppIntents.swift` | Siri Shortcuts：`AddWordIntent`（requestValueDialog 方式）、`TodayWordsIntent` |
| `VocabWidget/VocabWidget.swift` | WidgetKit：4 种尺寸，30 分钟刷新，Deep Link `quizapp://vocabulary` |
| `Views/Vocabulary/VocabularyHomeView.swift` | 词汇主页；含 `WordBookDetailView`、`WordDetailSheet`、`WordEditSheet` |
| `Views/Vocabulary/UnknownWordsView.swift` | 不认识单词本：列出 `correctStreak==0` 的已学单词，支持闪卡练习、搜索、单词级别标记已掌握 |
| `Views/Vocabulary/WordAddViews.swift` | `ManualAddSheet`（手动添加）、`ScreenshotAddSheet`（截图 OCR 识词批量添加） |
| `Views/Vocabulary/` | `FlashCardView`、`WordChoiceView`、`WordNotebookView`、`VocabQRImportView` |
| `WordBooks/*.json` | 11 个内置词库 JSON（初中/高中/CET-4精选&完整/CET-6精选&完整/考研/托福/SAT/商务/技术） |
| `LexoraIconView.swift` | App 图标设计（紫色渐变 + L 字母），ImageRenderer 导出 1024×1024 PNG |

### UserDefaults 存储键

| Key | 内容 |
|-----|------|
| `vocab_books_v1` | 用户自建/导入词库（不含内置词库数据） |
| `vocab_records_v1` | SM-2 学习记录 |
| `vocab_daily_v1` / `vocab_daily_date_v1` | 每日单词缓存 |
| `vocab_builtin_enabled_v1` | 已启用的内置词库 UUID 列表 |
| `vocab_total_count_v1` | 总词数缓存（Widget 读取） |

### 内置词库加载机制
- 词库 JSON 文件打包进 App Bundle（`WordBooks/` 文件夹）
- 默认全部**未启用**，不占 UserDefaults 空间
- 用户点击"启用"后，异步从 Bundle 解析 JSON 加载进内存
- `save()` 只持久化用户词库 + 已启用 UUID 列表，不把内置单词写入 UserDefaults

### 单词自动补全机制
- **启动 / 回到前台**：`reload()` → `enrichPendingWords()` 扫描用户词库中释义为"（待补充释义）"的单词，在已启用内置词库里查找同名词，自动复制释义/音标/词性
- **启用新词库时**：`toggleBuiltInBook` 加载完成后调用 `checkEnrichmentProposal(for:bookWords:)`，统计用户词库中的匹配数，有则设置 `@Published var enrichmentProposal`，UI 弹 Alert 询问是否一键同步；用户确认后调用 `applyEnrichment(from:)`

### Siri 集成
- 触发短语（英文）：`"Add word in Lexora"`、`"Save word in Lexora"` 等，触发后 Siri 再问 "Which word do you want to add?"
- 参数通过 `@Parameter(title:, requestValueDialog:)` 在运行时收集，不在 phrases 中内联（避免 NLU 训练报错）
- 添加的单词写入 `UserDefaults.shared`（App Group），app 回到前台时 `reload()` 同步到内存

### 单词编辑
- `WordDetailSheet` 左上角铅笔按钮 → 打开 `WordEditSheet`（表单编辑释义、音标、词性、例句）
- 保存后调用 `VocabularyStore.updateWord(_:)`，`WordDetailSheet` 和列表通过 `liveWord` / `liveWords` 计算属性实时反映最新内容

### 不认识单词本
- `VocabularyStore.unknownWords`：`studyCount > 0 && correctStreak == 0 && !isMastered`，按学习次数降序
- `VocabularyStore.unknownCount`：用于 UI badge 和横幅显示
- `VocabularyHomeView` 中 `unknownWordsBanner`：有不认识单词时显示红色入口卡片
- **重要**：`UnknownWordsView` 进入闪卡时必须先把单词快照存入 `@State var flashCardWords`，再 `showFlashCard = true`。**不能**在 `navigationDestination` 里直接用 `vocabStore.unknownWords.shuffled()`——store 更新会触发 closure 重新执行，生成更短的数组，而 `currentIndex` 保持旧值，导致越界崩溃。

### FlashCardView 崩溃防护
- `@State private var isAnimating`：每次 `submitAnswer` 开始时置 `true`，0.25s 动画完成后置 `false`，防止快速点击导致多次触发
- `guard !isAnimating && !isFinished`：两个条件都要检查

### MainTabView
共 4 个 Tab（tag 0-3）：**推荐**（tag=0）/ **刷题**（tag=1）/ **背词**（tag=2）/ **设置**（tag=3）
- 推荐 Tab：顶部 Segmented 切换刷题/背词面板，各显示今日推荐列表及启动入口
- 刷题 Tab：分类答题 + 错题本入口（`wrongBookBanner`）；右上角托盘图标 → LibraryView（题库管理、试卷生成、拍照录题）；badge 显示 `store.dueQuestions.count`
- 背词 Tab：词库列表 + 不认识单词横幅；badge 显示 `vocabStore.dueCount`
- 设置 Tab：算法设置（→ AlgorithmSettingsView）、使用帮助（→ HelpView）、反馈与联系（邮件/微信）、关于 Lexora、隐私政策
- Deep Link `quizapp://vocabulary` 跳转到 tag=2

### 设置 Tab — 反馈与联系
- 邮件：`mailto:acboo2020@gmail.com`，预填主题 + 设备信息
- 微信：显示微信号 `danshengshuo`，点击复制到剪贴板，2 秒后恢复

### 设置 Tab — 分享 App
- `UIActivityViewController`（包装为 `ShareSheet: UIViewControllerRepresentable`）
- 分享内容：文字介绍 + App Store URL（占位链接 `apps.apple.com/app/lexora/id0000000000`，上架后替换）

### 多语言支持（国际化）
支持简体中文（默认）、繁体中文、英文，在「设置」Tab 语言区域切换，重启后生效。

**实现方式：**
- `en.lproj/Localizable.strings` 和 `zh-Hant.lproj/Localizable.strings` — 约 200 条翻译
- SwiftUI `Text("中文字符串")` 自动将字面量作为 `LocalizedStringKey` 查找，**无需修改 View 代码**
- 插值字符串格式（`Text("有 \(count) 道错题")`）需在 strings 文件中用格式符：Int → `%lld`，String → `%@`
  - 示例：`"有 %lld 道错题待复习" = "%lld questions due for review";`
- 语言切换：`UserDefaults.standard.set([langCode], forKey: "AppleLanguages")`，重启后 iOS 加载对应 .lproj
- 语言选择区域 Header 硬编码为 "语言 / Language"（**不走 Localizable.strings**），避免用户切换到不熟悉语言后看不懂这个入口

**注意：** 条件字符串（三目运算符返回 `String` 类型）**不会**自动本地化，需要显式包装为 `Text(LocalizedStringKey(str))`。

### LibraryView — 题库分享与图片说明
- **生成分享二维码**：点击后先弹确认 Alert（「生成分享码需要将题库数据上传至云端服务器（Cloudinary），确认继续？」），确认后才上传
- **导出 JSON**：如题库含有通过拍照录题添加的本地图片（`.file` 类型），先弹提示（「图片将无法在其他设备显示，建议改用二维码分享」），确认后导出
- `bankHasLocalImages(_:)` 辅助函数：`bank.questions.contains { $0.image?.type == .file }`
- 图片类型说明：`.asset`（内置）/ `.url`（已上传 Cloudinary）/ `.file`（拍照录题本地路径，导出后图片丢失）

### Xcode 配置（已完成，已 commit，下次 pull 无需重复）
1. **App 名称**：Lexora（`swiftUI_PracticeApp` → `LexoraApp`）
2. **URL Scheme**：`quizapp`（Info.plist）
3. **App Groups**：主 App + Widget Extension 均已配置 `group.com.acspace.Lexora`
4. **Widget Extension**：Bundle ID `com.acspace.Lexora.VocabWidget`
5. **WordBooks 文件夹**：已以 folder reference 方式加入主 App target

---

## App Store 上架准备

### 已完成
- `PrivacyInfo.xcprivacy`：主 App 和 VocabWidget 各一份，声明 `NSPrivacyAccessedAPICategoryUserDefaults`（Reason: `CA92.1`）
  - **注意**：`.xcprivacy` 不被 `PBXFileSystemSynchronizedRootGroup` 自动识别，需在 Xcode 中手动 Add Files 并勾选对应 target
- 隐私政策页面：`https://zhangyida-lab.github.io/lexora-privacy/`（中英双语，托管于 GitHub Pages）
  - 已说明 Cloudinary 仅在用户主动点击「生成分享二维码」时上传，不含个人信息
- App 图标：`Assets.xcassets/AppIcon` 已配置 1024×1024（`LexoraIconView.swift` 可重新导出）

### 待完成（提审前必须）
- Info.plist 补充相机和相册权限说明：
  - `NSCameraUsageDescription`（拍照录题功能使用）
  - `NSPhotoLibraryUsageDescription`（截图识词功能使用）
- App Store Connect：截图（至少 iPhone 6.5"）、App 描述、关键词、年龄分级
- App Store Connect 填写隐私政策 URL：`https://zhangyida-lab.github.io/lexora-privacy/`
- 分享 App 链接（`SettingsView` 中的 ShareSheet）：上架后将占位 App Store URL 替换为真实链接

---

## Debugging

### SwiftUI / 数据驱动 UI 崩溃
- **先查数据层，再查交互层**：SwiftUI 中大多数崩溃（尤其是数组越界）根因在计算属性或状态变量的响应式重算，而非手势/点击操作本身
- **数组越界**：首先检查所有依赖数组 index 的计算属性——在 State 发生变化时它们会重新求值，可能在 `currentIndex` 还未更新前就返回更短的数组
  - 典型案例：`navigationDestination` 里直接用 `store.someArray.shuffled()` 作为 FlashCardView 数据源，store 更新触发 closure 重新执行，新数组比旧 `currentIndex` 短 → 越界崩溃
  - **解法**：进入闪卡前先把数据快照存入 `@State var snapshot`，闪卡只读 snapshot，不读 live store
- **快速点击 / 动画期间重复触发**：用 `@State private var isAnimating` + `guard !isAnimating` 双重防护，动画结束后再置 `false`
