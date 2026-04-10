import SwiftUI
import SwiftData 

// MARK: - 历史试卷列表

struct ExamHistoryView: View {
    @EnvironmentObject private var store: QuizStore
    @State private var paperToDelete: ExamPaper? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            if store.examPapers.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        summaryBar
                        ForEach(store.examPapers) { paper in
                            NavigationLink(destination: PaperDetailView(paper: paper)) {
                                PaperCard(paper: paper)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    paperToDelete = paper
                                    showDeleteConfirm = true
                                } label: {
                                    Label("删除试卷", systemImage: "trash")
                                }
                            }
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("历史试卷")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("确定删除这份试卷及所有作答记录？",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let p = paperToDelete { store.deleteExamPaper(p) }
                paperToDelete = nil
            }
            Button("取消", role: .cancel) { paperToDelete = nil }
        }
    }

    // MARK: 空状态
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 52)).foregroundColor(Color.quizPurpleLight.opacity(0.5))
            Text("暂无历史试卷").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
            Text("完成一次考试后，试卷和成绩\n将自动保存在这里")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: 汇总栏
    var summaryBar: some View {
        HStack(spacing: 10) {
            HistoryStatPill(icon: "doc.text.fill",
                            value: "\(store.examPapers.count)",
                            label: "试卷数")
            HistoryStatPill(icon: "checkmark.seal.fill",
                            value: "\(store.examPapers.flatMap { $0.attempts }.count)",
                            label: "总作答")
            HistoryStatPill(icon: "trophy.fill",
                            value: bestPercentageText,
                            label: "最高得分率")
        }
    }

    var bestPercentageText: String {
        let all = store.examPapers.compactMap { $0.bestAttempt }
        guard !all.isEmpty else { return "—" }
        let best = all.max(by: { $0.percentage < $1.percentage })!
        return "\(best.percentage)%"
    }
}

// MARK: - 试卷卡片

private struct PaperCard: View {
    let paper: ExamPaper

    var body: some View {
        VStack(spacing: 0) {
            // 顶部信息
            HStack(alignment: .top, spacing: 12) {
                modeIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(paper.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text(dateText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let best = paper.bestAttempt {
                    bestScoreBadge(best)
                } else {
                    Text("未作答")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.quizBorder.opacity(0.3))
                        .clipShape(Capsule())
                }
            }
            .padding(14)

            // 底部统计行（只有作答记录时显示）
            if !paper.attempts.isEmpty {
                Divider().background(Color.quizBorder)
                HStack(spacing: 0) {
                    paperStat(icon: "arrow.counterclockwise",
                              label: "作答 \(paper.attempts.count) 次")
                    Divider().background(Color.quizBorder).frame(height: 20)
                    paperStat(icon: "clock",
                              label: durationText)
                    Divider().background(Color.quizBorder).frame(height: 20)
                    paperStat(icon: "chevron.right",
                              label: "查看详情",
                              color: Color.quizPurpleLight)
                }
                .frame(height: 36)
            }
        }
        .background(Color.quizCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizBorder, lineWidth: 0.5))
    }

    var modeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(modeColor.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: paper.config.examMode == .exam ? "lock.fill" : "bolt.fill")
                .font(.system(size: 14))
                .foregroundColor(modeColor)
        }
    }

    var modeColor: Color {
        paper.config.examMode == .exam
            ? Color(red: 0.20, green: 0.55, blue: 0.80)
            : Color.quizGreen
    }

    var dateText: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "M月d日 HH:mm"
        return df.string(from: paper.createdAt)
    }

    var durationText: String {
        guard let last = paper.lastAttempt else { return "—" }
        return last.durationText
    }

    func bestScoreBadge(_ attempt: ExamAttempt) -> some View {
        let color: Color = attempt.percentage >= 90 ? Color.quizGreen
                         : attempt.percentage >= 75 ? Color.quizPurpleLight
                         : attempt.percentage >= 60 ? Color(red: 0.86, green: 0.55, blue: 0.25)
                         : Color.quizRed
        return VStack(spacing: 1) {
            Text("\(attempt.earnedScore)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            Text("/ \(attempt.totalScore)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    func paperStat(icon: String, label: String, color: Color = .secondary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(label).font(.system(size: 11))
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 试卷详情

struct PaperDetailView: View {
    let paper: ExamPaper
    @EnvironmentObject private var store: QuizStore
    @State private var showRetake = false

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    configCard
                    if !paper.attempts.isEmpty {
                        attemptsSection
                    }
                    retakeButton
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(paper.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $showRetake) {
            ExamContainerView(
                config: paper.config,
                questions: paper.questions,
                questionScores: paper.questionScores,
                existingPaperId: paper.id
            )
            .environmentObject(store)
        }
    }

    // MARK: 配置卡片
    var configCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("试卷配置", systemImage: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.quizPurpleLight)

            let rows: [(String, String)] = [
                ("科目", paper.config.subjects.sorted().joined(separator: "、")),
                ("难度", paper.config.difficulties.sorted().map { String(repeating: "★", count: $0) }.joined(separator: "  ")),
                ("模式", paper.config.examMode.rawValue),
                ("计分", paper.config.scoreMode.rawValue),
                ("题数", "\(paper.questions.count) 题"),
                ("总分", "\(paper.config.totalScore) 分"),
                ("创建", dateText(paper.createdAt)),
            ]
            ForEach(rows, id: \.0) { (k, v) in
                HStack {
                    Text(k).font(.system(size: 13)).foregroundColor(.secondary).frame(width: 40, alignment: .leading)
                    Text(v).font(.system(size: 13)).foregroundColor(.white)
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(Color.quizCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizBorder, lineWidth: 0.5))
    }

    // MARK: 作答记录
    var attemptsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("作答记录").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)

            ForEach(Array(paper.attempts.enumerated().reversed()), id: \.element.id) { offset, attempt in
                AttemptRow(attempt: attempt, index: paper.attempts.count - offset)
            }
        }
    }

    // MARK: 重新作答
    var retakeButton: some View {
        Button { showRetake = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise.circle.fill").font(.system(size: 16))
                Text("重新作答").font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.quizPurple)
            .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }

    func dateText(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy年M月d日 HH:mm"
        return df.string(from: date)
    }
}

// MARK: - 单次作答行

private struct AttemptRow: View {
    let attempt: ExamAttempt
    let index: Int

    var gradeColor: Color {
        switch attempt.percentage {
        case 90...100: return Color.quizGreen
        case 75..<90:  return Color.quizPurpleLight
        case 60..<75:  return Color(red: 0.86, green: 0.55, blue: 0.25)
        default:       return Color.quizRed
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 序号
            ZStack {
                Circle().fill(Color.quizBorder.opacity(0.3)).frame(width: 30, height: 30)
                Text("#\(index)").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(dateText(attempt.finishedAt))
                    .font(.system(size: 12)).foregroundColor(.secondary)
                HStack(spacing: 6) {
                    Text("答对 \(attempt.correctCount)/\(attempt.totalCount) 题")
                        .font(.system(size: 12)).foregroundColor(.white)
                    Text("·").foregroundColor(.secondary)
                    Text(attempt.durationText)
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
            }

            Spacer()

            // 得分
            VStack(spacing: 2) {
                Text("\(attempt.earnedScore)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(gradeColor)
                Text("\(attempt.percentage)%")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.quizCard)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))
    }

    func dateText(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "M月d日 HH:mm"
        return df.string(from: date)
    }
}

// MARK: - 统计胶囊

private struct HistoryStatPill: View {
    let icon: String; let value: String; let label: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Color.quizPurpleLight)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                Text(label).font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(Color.quizCard)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))
    }
}

#Preview {
    NavigationStack { ExamHistoryView() }
        .environmentObject(QuizStore(modelContext: try! ModelContainer(for:
  QuestionBankEntity.self, WrongRecordEntity.self, ExamPaperEntity.self,
  AppSettingsEntity.self).mainContext))
        .preferredColorScheme(.dark)
}
