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
    @State private var isExporting        = false
    @State private var exportError: String? = nil
    @State private var showExportError    = false
    @State private var qrShareURL: String? = nil
    @State private var qrBankName: String  = ""
    @State private var showQRSheet         = false
    @State private var showQRScanner       = false

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    summarySection
                    actionButtons
                    if !store.allCategories.isEmpty {
                        categoryManageSection
                    }
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
        .alert("导出失败", isPresented: $showExportError) {
            Button("好的") {}
        } message: {
            Text(exportError ?? "图片上传失败，请检查网络连接")
        }
        .sheet(isPresented: $showQRSheet) {
            if let url = qrShareURL {
                QRCodeShareView(bankName: qrBankName, shareURL: url)
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRImportView()
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
        VStack(spacing: 10) {
            // 生成试卷（主要入口）
            NavigationLink(destination: ExamConfigView()) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 16))
                    Text("生成试卷").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                }
                .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 14)
                .background(LinearGradient(
                    colors: [Color.quizPurple, Color(red: 0.20, green: 0.55, blue: 0.80)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(store.allQuestions.isEmpty)

            // 历史试卷
            NavigationLink(destination: ExamHistoryView()) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 16))
                    Text("历史试卷").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if !store.examPapers.isEmpty {
                        Text("\(store.examPapers.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.quizPurpleLight)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.quizPurple.opacity(0.25))
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color.quizPurpleLight.opacity(0.6))
                }
                .foregroundColor(Color.quizPurpleLight)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.quizPurple.opacity(0.15))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizPurple.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())

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
                showQRScanner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder").font(.system(size: 15))
                    Text("扫码导入").font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color.quizPurpleLight).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.quizPurple.opacity(0.2)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizPurple.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
            } // end HStack（导入 / 扫码）

            // 导出全部（JSON 文件）
            Button {
                Task { await exportAll() }
            } label: {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView().tint(Color.quizPurpleLight).scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up.fill").font(.system(size: 15))
                    }
                    Text(isExporting ? "上传中…" : "导出全部").font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color.quizPurpleLight).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.quizPurple.opacity(0.2)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizPurple.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(store.allQuestions.isEmpty || isExporting)

            // 生成全部题库二维码
            Button {
                Task { await generateQRForAll() }
            } label: {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "qrcode").font(.system(size: 15))
                    }
                    Text(isExporting ? "生成中…" : "生成分享二维码").font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(isExporting ? Color.quizPurple.opacity(0.5) : Color.quizPurple)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(store.allQuestions.isEmpty || isExporting)
        } // end VStack
        .padding(.horizontal, 16)
    }

    // MARK: 分类管理
    var categoryManageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("分类管理").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Spacer()
                let hiddenCount = store.allCategories.filter { store.isCategoryHidden($0.name) }.count
                if hiddenCount > 0 {
                    Text("已隐藏 \(hiddenCount) 个")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(store.allCategories) { cat in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(cat.color.opacity(store.isCategoryHidden(cat.name) ? 0.06 : 0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: cat.icon)
                                .font(.system(size: 15))
                                .foregroundColor(store.isCategoryHidden(cat.name) ? cat.color.opacity(0.35) : cat.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(store.isCategoryHidden(cat.name) ? .secondary : .white)
                            Text("\(cat.questionCount) 题")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if store.isCategoryHidden(cat.name) {
                            Text("已隐藏")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.quizBorder)
                                .cornerRadius(6)
                        }

                        Toggle("", isOn: Binding(
                            get: { !store.isCategoryHidden(cat.name) },
                            set: { _ in store.toggleCategoryHidden(cat.name) }
                        ))
                        .tint(cat.color)
                        .labelsHidden()
                        .scaleEffect(0.85)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .opacity(store.isCategoryHidden(cat.name) ? 0.6 : 1.0)

                    if cat.id != store.allCategories.last?.id {
                        Divider().background(Color.quizBorder).padding(.leading, 60)
                    }
                }
            }
            .background(Color.quizCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizBorder, lineWidth: 0.5))
            .padding(.horizontal, 16)
        }
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
                                 Task { await exportBank(bank) }
                             },
                             onQRShare: {
                                 Task { await generateQR(for: bank) }
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

    // MARK: 导出处理（async，自动上传本地图片）
    func exportAll() async {
        isExporting = true
        defer { isExporting = false }
        do {
            let data = try await store.exportAllAsBankForSharing()
            if let url = writeTempFile(data, name: "all_questions") {
                exportURL = url
                showExportSheet = true
            }
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
    }

    func exportBank(_ bank: QuestionBank) async {
        isExporting = true
        defer { isExporting = false }
        do {
            let data = try await store.exportBankForSharing(bank)
            if let url = writeTempFile(data, name: bank.name) {
                exportURL = url
                showExportSheet = true
            }
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
    }

    func generateQRForAll() async {
        isExporting = true
        defer { isExporting = false }
        do {
            let url = try await store.shareAllBanksAsURL()
            qrShareURL = url
            qrBankName = "全部题库"
            showQRSheet = true
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
    }

    func generateQR(for bank: QuestionBank) async {
        isExporting = true
        defer { isExporting = false }
        do {
            let url = try await store.shareBankAsURL(bank)
            qrShareURL = url
            qrBankName = bank.name
            showQRSheet = true
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
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
    let onQRShare: () -> Void
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
                Divider().background(Color.quizBorder).frame(height: 30)
                bankActionButton(icon: "qrcode", label: "二维码", action: onQRShare)
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
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = vc.popoverPresentationController {
            popover.sourceView = UIView()
            popover.permittedArrowDirections = []
        }
        return vc
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { LibraryView() }
        .environmentObject(QuizStore(modelContext: try! ModelContainer(for:
  QuestionBankEntity.self, WrongRecordEntity.self, ExamPaperEntity.self,
  AppSettingsEntity.self).mainContext))
        .preferredColorScheme(.dark)
}
