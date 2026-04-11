import SwiftUI
import SwiftData

@main
struct LexoraApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var store: QuizStore
    @StateObject private var vocabStore = VocabularyStore()
    @StateObject private var algoStore  = AlgorithmSettingsStore()

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

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(vocabStore)
                .environmentObject(algoStore)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                vocabStore.reload()
            }
        }
    }
}
