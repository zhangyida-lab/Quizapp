import SwiftUI

@main
struct swiftUI_PracticeApp: App {
    @StateObject private var store = QuizStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
