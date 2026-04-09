import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - 二维码分享视图

struct QRCodeShareView: View {
    let bankName: String
    let shareURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.quizBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // 说明
                        VStack(spacing: 6) {
                            Text("扫码导入题库").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                            Text("使用 App 内「导入 JSON」扫描下方二维码，或直接复制链接")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // 二维码
                        if let qrImage = generateQRCode(from: shareURL) {
                            VStack(spacing: 12) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 220, height: 220)
                                    .padding(16)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

                                Text(bankName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(Color.quizCard)
                                    .frame(width: 220, height: 220)
                                Image(systemName: "qrcode").font(.system(size: 60))
                                    .foregroundColor(.secondary)
                            }
                        }

                        // URL 复制区
                        VStack(spacing: 10) {
                            Text("题库链接").font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 10) {
                                Text(shareURL)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color.quizPurpleLight)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    UIPasteboard.general.string = shareURL
                                    withAnimation { copied = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { copied = false }
                                    }
                                } label: {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 14))
                                        .foregroundColor(copied ? Color.quizGreen : Color.quizPurpleLight)
                                        .frame(width: 36, height: 36)
                                        .background(Color.quizPurple.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(12)
                            .background(Color.quizCard)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.quizBorder, lineWidth: 0.5))
                        }
                        .padding(.horizontal, 24)

                        // 分享按钮
                        Button {
                            shareLink()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 15))
                                Text("分享链接").font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.quizPurple).cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 24)

                        // 使用说明
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle").font(.system(size: 12))
                                    .foregroundColor(Color.quizPurpleLight)
                                Text("使用说明").font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.quizPurpleLight)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                infoRow("对方打开 App → 题库 → 导入 JSON → 粘贴链接")
                                infoRow("或直接扫描二维码自动填入链接")
                                infoRow("链接长期有效，可重复分享")
                            }
                        }
                        .padding(14)
                        .background(Color.quizCard)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.quizBorder, lineWidth: 0.5))
                        .padding(.horizontal, 24)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("分享题库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(Color.quizPurpleLight)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: 辅助

    func infoRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·").foregroundColor(.secondary)
            Text(text).font(.system(size: 12)).foregroundColor(.secondary)
        }
    }

    func shareLink() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first?.rootViewController else { return }
        let ac = UIActivityViewController(activityItems: [shareURL], applicationActivities: nil)
        if let popover = ac.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX,
                                        y: root.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        root.present(ac, animated: true)
    }

    func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data,  forKey: "inputMessage")
        filter.setValue("H",   forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
