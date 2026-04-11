import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject private var store: QuizStore
    @EnvironmentObject private var vocabStore: VocabularyStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            // Tab 0: 今日
            NavigationStack {
                DailyReviewView()
            }
            .tabItem {
                Label("今日", systemImage: "calendar.badge.clock")
            }
            .tag(0)

            // Tab 1: 答题（含错题本入口）
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("答题", systemImage: "questionmark.circle.fill")
            }
            .badge(store.dueQuestions.count > 0 ? store.dueQuestions.count : 0)
            .tag(1)

            // Tab 2: 词汇（含生词本入口）
            NavigationStack {
                VocabularyHomeView()
            }
            .tabItem {
                Label("词汇", systemImage: "text.book.closed.fill")
            }
            .badge(vocabStore.dueCount > 0 ? vocabStore.dueCount : 0)
            .tag(2)

            // Tab 3: 题库（含录题入口）
            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("题库", systemImage: "tray.full.fill")
            }
            .tag(3)
        }
        .tint(Color.quizPurpleLight)
        .onOpenURL { url in
            if url.scheme == "quizapp" && url.host == "vocabulary" {
                selectedTab = 2
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(QuizStore(modelContext: try! ModelContainer(for:
            QuestionBankEntity.self, WrongRecordEntity.self, ExamPaperEntity.self,
            AppSettingsEntity.self).mainContext))
        .environmentObject(VocabularyStore())
        .preferredColorScheme(.dark)
}
