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
