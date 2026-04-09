import SwiftUI
import AVFoundation

// MARK: - 扫码导入视图

struct QRImportView: View {
    @EnvironmentObject private var store: QuizStore
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
                    // 相机预览
                    QRScannerRepresentable(scannedCode: $scannedURL,
                                          isActive: !isImporting && !showResult)
                        .ignoresSafeArea()

                    scanOverlay
                } else {
                    permissionDeniedView
                }
            }
            .navigationTitle("扫码导入题库")
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
                else { scannedURL = nil }  // 重置，允许重新扫码
            }
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: 扫码框 + 状态提示
    var scanOverlay: some View {
        VStack(spacing: 0) {
            Spacer()

            // 扫描框
            ZStack {
                // 半透明遮罩（挖空中间）
                ScanMaskShape()
                    .fill(Color.black.opacity(0.5))
                    .ignoresSafeArea()

                // 扫描框边角
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.quizPurple, lineWidth: 2.5)
                    .frame(width: 240, height: 240)

                // 四角装饰
                CornerLines()
                    .stroke(Color.quizPurpleLight, lineWidth: 4)
                    .frame(width: 240, height: 240)
            }
            .frame(height: 300)

            Spacer()

            // 底部提示
            VStack(spacing: 16) {
                if isImporting {
                    HStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("正在下载并导入题库…")
                            .font(.system(size: 15)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Color.quizPurple.opacity(0.85))
                    .cornerRadius(14)
                } else {
                    Text("将二维码对准框内自动识别")
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

    // MARK: 从 URL 下载并导入题库
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
            try store.importBank(from: data)
            let name = store.questionBanks.last?.name ?? "题库"
            isImporting = false
            importSuccess = true
            resultTitle   = "导入成功 🎉"
            resultMessage = "「\(name)」已添加到你的题库，共 \(store.questionBanks.last?.questions.count ?? 0) 道题"
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

// MARK: - AVFoundation 扫码器

struct QRScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    let isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: ScannerViewController, context: Context) {
        if isActive { vc.startRunning() }
        else        { vc.stopRunning()  }
    }

    class Coordinator: NSObject, ScannerViewControllerDelegate {
        let parent: QRScannerRepresentable
        init(_ parent: QRScannerRepresentable) { self.parent = parent }
        func didScan(code: String) {
            DispatchQueue.main.async { self.parent.scannedCode = code }
        }
    }
}

// MARK: - 扫码 ViewController

protocol ScannerViewControllerDelegate: AnyObject {
    func didScan(code: String)
}

final class ScannerViewController: UIViewController {
    weak var delegate: ScannerViewControllerDelegate?
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRunning()
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device) else { return }

        let session = AVCaptureSession()
        guard session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame        = view.bounds
        view.layer.insertSublayer(preview, at: 0)

        self.session      = session
        self.previewLayer = preview
    }

    func startRunning() {
        hasScanned = false
        guard let session, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func stopRunning() {
        guard let session, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
    }
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let obj   = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        hasScanned = true
        stopRunning()
        delegate?.didScan(code: value)
    }
}

// MARK: - 扫描框装饰

struct ScanMaskShape: Shape {
    let holeSize: CGFloat = 240
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let hole = CGRect(
            x: rect.midX - holeSize / 2,
            y: rect.midY - holeSize / 2,
            width: holeSize, height: holeSize
        )
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: 16, height: 16))
        return path
    }
}

struct CornerLines: Shape {
    let len: CGFloat = 28
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY + len), CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + len, y: rect.minY)),
            (CGPoint(x: rect.maxX - len, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + len)),
            (CGPoint(x: rect.maxX, y: rect.maxY - len), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX - len, y: rect.maxY)),
            (CGPoint(x: rect.minX + len, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY - len)),
        ]
        for (a, b, c) in corners {
            p.move(to: a); p.addLine(to: b); p.addLine(to: c)
        }
        return p
    }
}
