import AppIntents

// MARK: - 添加生词 Intent
struct AddWordIntent: AppIntent {

    static var title: LocalizedStringResource = "添加生词"
    static var description = IntentDescription(
        "将一个英语单词快速添加到你的生词本，无需打开 App",
        categoryName: "词汇学习"
    )

    @Parameter(title: "单词", description: "要添加的英文单词",
               requestValueDialog: IntentDialog("Which word do you want to add?"))
    var term: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let success = VocabSharedHelper.quickAdd(word: term)
        if success {
            return .result(dialog: "已将「\(term)」加入生词本，记得之后补充释义 📖")
        } else {
            return .result(dialog: "「\(term)」已经在你的词库里了 ✅")
        }
    }
}

// MARK: - 查看今日单词 Intent
struct TodayWordsIntent: AppIntent {

    static var title: LocalizedStringResource = "今日单词"
    static var description = IntentDescription(
        "查看今天待复习的单词数量",
        categoryName: "词汇学习"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let stats = VocabSharedHelper.stats()
        if stats.dueCount == 0 {
            return .result(dialog: "今天没有待复习的单词，已掌握 \(stats.masteredCount) 个 🎉")
        } else {
            return .result(dialog: "今天有 \(stats.dueCount) 个单词待复习，加油！💪")
        }
    }
}

// MARK: - Siri 推荐短语
struct VocabAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddWordIntent(),
            phrases: [
                "Add word in \(.applicationName)",
                "Save word in \(.applicationName)",
                "Remember word in \(.applicationName)",
                "添加生词 in \(.applicationName)",
                "记单词 in \(.applicationName)"
            ],
            shortTitle: "Add Word",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: TodayWordsIntent(),
            phrases: [
                "Word review today",
                "My vocab today",
                "今天有几个单词要复习",
                "我今天的单词复习情况",
                "Check today's vocabulary in \(.applicationName)"
            ],
            shortTitle: "Today's Words",
            systemImageName: "calendar"
        )
    }
}
