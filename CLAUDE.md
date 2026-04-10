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

**Navigation:** `MainTabView` (5 tabs) wraps each tab in its own `NavigationStack`. Deep navigation uses `NavigationLink` and `.navigationDestination`.

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
| `Views/ExamContainerView.swift` | Exam session: creates/links paper in store on `.onAppear`, saves `ExamAttempt` via `.onChange(of: vm.isFinished)`, `ExamResultView`, `ExamPDFGenerator` |
| `Views/ExamHistoryView.swift` | Lists saved `ExamPaper`s, `PaperDetailView` with attempt history and re-take button |
| `Views/LibraryView.swift` | Question bank management, entry points to ExamConfigView and ExamHistoryView |

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

## Vocabulary Module（feature/vocabulary-learning 分支）

### 架构概述
词汇模块是独立功能分支，**不使用 SwiftData**，采用 `UserDefaults + JSONEncoder` + `ObservableObject`，原因是 Widget Extension 和 Siri App Intent 需要跨进程读写，SwiftData 不支持跨 target 共享。

**App Group ID：** `group.com.acspace.swiftUI-Practice`

### 核心文件

| 文件 | 职责 |
|------|------|
| `Models/Word.swift` | `Word`、`WordBook`、`WordRecord`（SM-2）、`WordBookImport`（宽松解析） |
| `Store/VocabularyStore.swift` | 主 ObservableObject，管理词库/记录/TTS/每日单词 |
| `Store/BuiltInWordBooks.swift` | 11 个内置词库目录（指向 Bundle JSON），懒加载 |
| `Store/VocabSharedHelper.swift` | 轻量静态层，供 Widget/Siri Extension 使用，含 `UserDefaults.shared` 定义 |
| `VocabAppIntents.swift` | Siri Shortcuts：`AddWordIntent`、`TodayWordsIntent` |
| `VocabWidget/VocabWidget.swift` | WidgetKit：4 种尺寸，30 分钟刷新，Deep Link `quizapp://vocabulary` |
| `Views/Vocabulary/` | `VocabularyHomeView`、`FlashCardView`、`WordChoiceView`、`WordNotebookView`、`VocabQRImportView` |
| `WordBooks/*.json` | 11 个内置词库 JSON（初中/高中/CET-4精选&完整/CET-6精选&完整/考研/托福/SAT/商务/技术） |

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

### MainTabView
共 6 个 Tab（tag 0-5）：首页 / 今日 / 错题本 / **词汇**（tag=3）/ 题库 / 录题
词汇 Tab badge 显示 `vocabStore.dueCount`，Deep Link `quizapp://vocabulary` 跳转到 tag=3

### 待完成的 Xcode 配置（Mac 上操作一次，commit 后永久生效）
1. **URL Scheme**：主 App target → Info → URL Types → 添加 `quizapp`
2. **App Groups**：主 App target → Signing & Capabilities → App Groups → `group.com.acspace.swiftUI-Practice`
3. **创建 Widget Extension target**：File → New → Target → Widget Extension，命名 `VocabWidget`，删除默认生成文件
4. **VocabWidget target 配置**：
   - App Groups 能力 → `group.com.acspace.swiftUI-Practice`
   - Target Membership 勾选：`VocabWidget.swift`、`Word.swift`、`VocabSharedHelper.swift`
5. **WordBooks 文件夹**：拖入 Xcode，选 "Create folder references"，勾选主 App target
6. **配置完后务必 commit `project.pbxproj` 和 `.entitlements` 文件**，下次 pull 无需重复配置
