import SwiftUI
import AVFoundation

// MARK: - 词库扫码导入
// 复用 QRScannerView.swift 中的 QRScannerRepresentable / ScanMaskShape / CornerLines

struct VocabQRImportView: View {
    @EnvironmentObject private var vocabStore: VocabularyStore
    @Environment(\.dismiss) private var dismiss

    @State private var scannedURL: String?  = nil
    @State private var isImporting          = false
    @State private var resultTitle          = ""
    @State private var resultMessage        = ""
    @State private var showResult           = false
    @State private var importSuccess        = false
    @State private var cameraPermission     = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if cameraPermission == .authorized || cameraPermission == .notDetermined {
                    QRScannerRepresentable(scannedCode: $scannedURL,
                                          isActive: !isImporting && !showResult)
                        .ignoresSafeArea()
                    scanOverlay
                } else {
                    permissionDeniedView
                }
            }
            .navigationTitle("扫码导入词库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(Color.quizPurpleLight)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scannedURL) { _, url in
            guard let url, !isImporting else { return }
            Task { await importFromURL(url) }
        }
        .onAppear {
            if cameraPermission == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        cameraPermission = granted ? .authorized : .denied
                    }
                }
            }
        }
        .alert(resultTitle, isPresented: $showResult) {
            Button("好的") {
                if importSuccess { dismiss() }
                else { scannedURL = nil }
            }
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: 扫描框
    var scanOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                ScanMaskShape()
                    .fill(Color.black.opacity(0.5))
                    .ignoresSafeArea()
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.quizPurple, lineWidth: 2.5)
                    .frame(width: 240, height: 240)
                CornerLines()
                    .stroke(Color.quizPurpleLight, lineWidth: 4)
                    .frame(width: 240, height: 240)
            }
            .frame(height: 300)
            Spacer()
            VStack(spacing: 16) {
                if isImporting {
                    HStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("正在下载并导入词库…")
                            .font(.system(size: 15)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Color.quizPurple.opacity(0.85))
                    .cornerRadius(14)
                } else {
                    Text("将词库二维码对准框内自动识别")
                        .font(.system(size: 15)).foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(12)
                }
            }
            .padding(.bottom, 60)
        }
    }

    // MARK: 无权限提示
    var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 56)).foregroundColor(.secondary)
            Text("需要相机权限")
                .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
            Text("请前往「设置 → 隐私与安全性 → 相机」\n允许本 App 使用相机")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("前往设置")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(Color.quizPurple).cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(40)
    }

    // MARK: 从 URL 下载导入
    func importFromURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            showError("无效的二维码", "扫描内容不是有效链接：\(urlString)")
            return
        }
        isImporting = true
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            try vocabStore.importWordBook(from: data)
            let name = vocabStore.wordBooks.last?.name ?? "词库"
            let count = vocabStore.wordBooks.last?.totalCount ?? 0
            isImporting   = false
            importSuccess = true
            resultTitle   = "导入成功 🎉"
            resultMessage = "「\(name)」已添加到你的词库，共 \(count) 个单词"
            showResult    = true
        } catch {
            isImporting = false
            showError("导入失败", error.localizedDescription)
        }
    }

    func showError(_ title: String, _ msg: String) {
        importSuccess = false
        resultTitle   = title
        resultMessage = msg
        showResult    = true
    }
}
