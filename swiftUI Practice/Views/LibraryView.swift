import SwiftUI
import UniformTypeIdentifiers

// MARK: - 题库管理

struct LibraryView: View {
    @EnvironmentObject private var store: QuizStore
    @State private var showImportPicker  = false
    @State private var showExportSheet   = false
    @State private var exportURL: URL?   = nil
    @State private var importError: String? = nil
    @State private var showImportError   = false
    @State private var bankToDelete: QuestionBank? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    summarySection
                    actionButtons
                    bankListSection
                    Spacer(minLength: 40)
                }
                .padding(.top, 16).padding(.bottom, 40)
            }
        }
        .navigationTitle("题库管理")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // 导入文件选择器
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        // 导出
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("导入失败", isPresented: $showImportError) {
            Button("好的") {}
        } message: {
            Text(importError ?? "JSON 格式不正确，请检查文件内容")
        }
        .confirmationDialog("确定删除这个题库？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let bank = bankToDelete { store.deleteBank(bank) }
                bankToDelete = nil
            }
            Button("取消", role: .cancel) { bankToDelete = nil }
        }
    }

    // MARK: 统计摘要
    var summarySection: some View {
        HStack(spacing: 12) {
            LibStatCard(icon: "tray.full.fill",       value: "\(store.questionBanks.count)", label: "题库数量", color: Color.quizPurpleLight)
            LibStatCard(icon: "doc.text.fill",         value: "\(store.allQuestions.count)",  label: "启用题目", color: Color.quizGreen)
            LibStatCard(icon: "square.grid.2x2.fill",  value: "\(store.categories.count)",    label: "分类数量", color: Color(red: 0.86, green: 0.55, blue: 0.25))
        }
        .padding(.horizontal, 16)
    }

    // MARK: 操作按钮
    var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showImportPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill").font(.system(size: 15))
                    Text("导入 JSON").font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.quizPurple).cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                if let data = try? store.exportAllAsBank() {
                    exportURL = writeTempFile(data, name: "all_questions")
                    showExportSheet = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill").font(.system(size: 15))
                    Text("导出全部").font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color.quizPurpleLight).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.quizPurple.opacity(0.2)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizPurple.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(store.allQuestions.isEmpty)
        }
        .padding(.horizontal, 16)
    }

    // MARK: 题库列表
    var bankListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的题库").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                ForEach(store.questionBanks) { bank in
                    BankCard(bank: bank,
                             onToggle: { store.toggleBankEnabled(bank) },
                             onExport: {
                                 if let data = try? store.exportBank(bank) {
                                     exportURL = writeTempFile(data, name: bank.name)
                                     showExportSheet = true
                                 }
                             },
                             onDelete: {
                                 if !bank.isBuiltIn {
                                     bankToDelete = bank
                                     showDeleteConfirm = true
                                 }
                             })
                }
            }
            .padding(.horizontal, 16)

            // JSON 格式说明
            jsonFormatSection
        }
    }

    // MARK: JSON 格式说明
    var jsonFormatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("JSON 格式说明").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(jsonFormatLines, id: \.self) { line in
                    Text(line).font(.system(size: 12, design: .monospaced)).foregroundColor(Color.quizPurpleLight.opacity(0.85))
                }
            }
            .padding(12).background(Color.black.opacity(0.4)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    let jsonFormatLines = [
        #"{"#,
        #"  "version": "1.0","#,
        #"  "name": "题库名称","#,
        #"  "questions": ["#,
        #"    {"#,
        #"      "category": "分类名"，"#,
        #"      "text": "题目内容","#,
        #"      "options": ["A","B","C","D"],"#,
        #"      "correctIndex": 0,"#,
        #"      "difficulty": 3,"#,
        #"      "explanation": "解析（可选）""#,
        #"    }"#,
        #"  ]"#,
        #"}"#,
    ]

    // MARK: 导出临时文件
    func writeTempFile(_ data: Data, name: String) -> URL? {
        let safeName = name.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName).json")
        try? data.write(to: url)
        return url
    }

    // MARK: 导入处理
    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                try store.importBank(from: data)
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }
}

// MARK: - 题库卡片

struct BankCard: View {
    let bank: QuestionBank
    let onToggle: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(iconColor.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: bank.isBuiltIn ? "star.fill" : "tray.fill")
                        .font(.system(size: 18)).foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(bank.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        if bank.isBuiltIn {
                            Text("内置").font(.system(size: 10))
                                .foregroundColor(Color.quizPurpleLight)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.quizPurple.opacity(0.25)).cornerRadius(4)
                        }
                    }
                    Text("\(bank.questions.count) 道题 · v\(bank.version)")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }

                Spacer()

                // 启用开关
                Toggle("", isOn: Binding(get: { bank.isEnabled }, set: { _ in onToggle() }))
                    .tint(Color.quizPurple).labelsHidden().scaleEffect(0.85)
            }
            .padding(14)

            // 操作行
            Divider().background(Color.quizBorder)

            HStack(spacing: 0) {
                bankActionButton(icon: "square.and.arrow.up", label: "导出", action: onExport)
                if !bank.isBuiltIn {
                    Divider().background(Color.quizBorder).frame(height: 30)
                    bankActionButton(icon: "trash", label: "删除", color: Color.quizRed, action: onDelete)
                }
            }
            .frame(height: 40)
        }
        .background(Color.quizCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizBorder, lineWidth: 0.5))
        .opacity(bank.isEnabled ? 1.0 : 0.5)
    }

    var iconColor: Color { bank.isBuiltIn ? Color.quizPurpleLight : Color(red: 0.86, green: 0.55, blue: 0.25) }

    func bankActionButton(icon: String, label: String, color: Color = Color.quizPurpleLight, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 12))
            }
            .foregroundColor(color).frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 统计卡片

struct LibStatCard: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.quizCard).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))
    }
}

// MARK: - ShareSheet（UIKit 封装）

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { LibraryView() }
        .environmentObject(QuizStore())
        .preferredColorScheme(.dark)
}
