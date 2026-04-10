import SwiftUI
import SwiftData

@main
struct swiftUI_PracticeApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var store: QuizStore

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
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
