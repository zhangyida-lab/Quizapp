import SwiftUI
import SwiftData

@main
struct LexoraApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var store: QuizStore
    @StateObject private var vocabStore = VocabularyStore()

    init() {
        let schema = Schema([
            QuestionBankEntity.self,
            WrongRecordEntity.self,
            ExamPaperEntity.self,
            AppSettingsEntity.self
        ])
        let container = try! ModelContainer(for: schema)
        self.modelContainer = container
        _store = StateObject(wrappedValue: QuizStore(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(vocabStore)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
