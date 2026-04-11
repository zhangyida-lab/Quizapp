import WidgetKit
import SwiftUI

// MARK: - 本地颜色（与主 App 保持一致）
private extension Color {
    static let wBg           = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let wCard         = Color(red: 0.17, green: 0.17, blue: 0.18)
    static let wPurple       = Color(red: 0.33, green: 0.29, blue: 0.72)
    static let wPurpleLight  = Color(red: 0.69, green: 0.66, blue: 0.93)
    static let wGreen        = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let wRed          = Color(red: 0.95, green: 0.30, blue: 0.30)
}

// MARK: - Deep Link URL
private let vocabDeepLink = URL(string: "quizapp://vocabulary")!

// MARK: - Timeline Entry
struct VocabEntry: TimelineEntry {
    let date: Date
    let stats: VocabStats
    let todayWords: [Word]
}

// MARK: - Timeline Provider
struct VocabTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> VocabEntry {
        VocabEntry(
            date: Date(),
            stats: VocabStats(totalWords: 1280, dueCount: 12, masteredCount: 45),
            todayWords: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (VocabEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocabEntry>) -> Void) {
        let entry = makeEntry()
        // 每 30 分钟刷新一次
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> VocabEntry {
        VocabEntry(
            date: Date(),
            stats: VocabSharedHelper.stats(),
            todayWords: VocabSharedHelper.todayWords(limit: 3)
        )
    }
}

// MARK: - Small Widget（首页 2×2）
struct SmallWidgetView: View {
    let entry: VocabEntry

    var body: some View {
        ZStack {
            Color.wBg
            VStack(spacing: 6) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color.wPurpleLight)

                Text("\(entry.stats.dueCount)")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)

                Text("待复习")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("共 \(entry.stats.totalWords) 词")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Medium Widget（首页 4×2）
struct MediumWidgetView: View {
    let entry: VocabEntry

    var body: some View {
        ZStack {
            Color.wBg
            HStack(spacing: 0) {
                // 左：统计
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.book.closed.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.wPurpleLight)
                        Text("词汇学习")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        StatRow(icon: "clock.arrow.circlepath", value: "\(entry.stats.dueCount)", label: "待复习", color: .wPurpleLight)
                        StatRow(icon: "checkmark.seal.fill",    value: "\(entry.stats.masteredCount)", label: "已掌握", color: .wGreen)
                        StatRow(icon: "books.vertical.fill",    value: "\(entry.stats.totalWords)", label: "总词数", color: .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)

                Divider()
                    .background(Color.wCard)
                    .padding(.vertical, 12)

                // 右：今日单词
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日单词")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)

                    if entry.todayWords.isEmpty {
                        Text("今日已完成 🎉")
                            .font(.system(size: 11))
                            .foregroundColor(.wGreen)
                    } else {
                        ForEach(entry.todayWords.prefix(3)) { word in
                            HStack(spacing: 4) {
                                Text(word.word)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(word.partOfSpeech)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.wPurpleLight)
                            }
                            Text(word.primaryMeaning)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
            }
        }
    }
}

private struct StatRow: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
                .frame(width: 14)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 锁屏 Circular Widget
struct CircularWidgetView: View {
    let entry: VocabEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Text("\(entry.stats.dueCount)")
                    .font(.system(size: 20, weight: .bold))
                Text("待复习")
                    .font(.system(size: 8))
            }
        }
    }
}

// MARK: - 锁屏 Rectangular Widget
struct RectangularWidgetView: View {
    let entry: VocabEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.stats.dueCount == 0 ? "今日已完成 ✅" : "待复习 \(entry.stats.dueCount) 个")
                    .font(.system(size: 13, weight: .semibold))
                Text("已掌握 \(entry.stats.masteredCount) / \(entry.stats.totalWords) 词")
                    .font(.system(size: 11))
            }
        }
    }
}

// MARK: - Widget 主体
struct VocabWidget: Widget {
    let kind = "VocabWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VocabTimelineProvider()) { entry in
            Link(destination: vocabDeepLink) {
                widgetView(entry: entry)
                    .widgetURL(vocabDeepLink)
            }
        }
        .configurationDisplayName("词汇学习")
        .description("查看待复习单词数量和今日学习进度")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }

    @ViewBuilder
    private func widgetView(entry: VocabEntry) -> some View {
        // WidgetKit 会根据当前 family 自动选择
        // 这里使用 containerBackground 适配 iOS 17
        Group {
            SmallOrMediumView(entry: entry)
        }
        .containerBackground(Color.wBg, for: .widget)
    }
}

// 根据 family 分发视图
private struct SmallOrMediumView: View {
    @Environment(\.widgetFamily) var family
    let entry: VocabEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Bundle Entry Point
@main
struct VocabWidgetBundle: WidgetBundle {
    var body: some Widget {
        VocabWidget()
    }
}
