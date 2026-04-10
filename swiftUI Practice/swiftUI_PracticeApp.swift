import SwiftUI

@main
struct swiftUI_PracticeApp: App {
    @StateObject private var store = QuizStore()
    @StateObject private var vocabStore = VocabularyStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .environmentObject(vocabStore)
                .preferredColorScheme(.dark)
        }
    }
}
