import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: QuizStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            // Tab 1: 首页
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }
            .tag(0)

            // Tab 2: 今日推荐
            NavigationStack {
                DailyReviewView()
            }
            .tabItem {
                Label("今日", systemImage: "calendar.badge.clock")
            }
            .tag(1)

            // Tab 3: 错题本
            NavigationStack {
                WrongBookView()
            }
            .tabItem {
                Label("错题本", systemImage: "bookmark.fill")
            }
            .badge(store.dueQuestions.count > 0 ? store.dueQuestions.count : 0)
            .tag(2)

            // Tab 4: 题库
            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("题库", systemImage: "tray.full.fill")
            }
            .tag(3)

            // Tab 5: 拍照录题
            NavigationStack {
                PhotoCaptureView()
            }
            .tabItem {
                Label("录题", systemImage: "camera.fill")
            }
            .tag(4)
        }
        .tint(Color.quizPurpleLight)
    }
}

#Preview {
    MainTabView()
        .environmentObject(QuizStore())
        .preferredColorScheme(.dark)
}
