import SwiftUI

// MARK: - Lexora App Icon
// 在 Preview 中预览效果，或点击"导出"按钮保存 PNG 到相册

struct LexoraIconView: View {
    var size: CGFloat = 400

    private func u(_ percent: CGFloat) -> CGFloat { size * percent / 100 }

    var body: some View {
        ZStack {
            background
            glow
            rays
            letterL
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: u(22.5), style: .continuous))
    }

    // MARK: 深紫渐变背景
    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.29, green: 0.17, blue: 0.56), // #4A2C8F
                Color(red: 0.48, green: 0.31, blue: 0.83)  // #7B4FD4
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: 中心柔光
    private var glow: some View {
        Ellipse()
            .fill(Color.white.opacity(0.09))
            .frame(width: u(75), height: u(65))
            .blur(radius: u(12))
            .offset(x: u(4), y: -u(6))
    }

    // MARK: 放射光线（从 L 顶端向右上方散射）
    private var rays: some View {
        let configs: [(angle: Double, length: CGFloat, width: CGFloat, opacity: Double)] = [
            (28, u(27), u(1.8), 0.45),
            (44, u(21), u(1.4), 0.30),
            (60, u(16), u(1.1), 0.20),
            (76, u(12), u(0.9), 0.12),
        ]
        return ZStack {
            ForEach(Array(configs.enumerated()), id: \.offset) { _, c in
                Capsule()
                    .fill(Color.white.opacity(c.opacity))
                    .frame(width: c.width, height: c.length)
                    .offset(y: -c.length / 2)
                    .rotationEffect(.degrees(c.angle), anchor: .bottom)
                    // 光线锚点 = L 顶端
                    .offset(x: -u(12), y: -u(19))
            }
        }
    }

    // MARK: 字母 L（书脊 + 展开页面）
    private var letterL: some View {
        let strokeW = u(13)
        let vH      = u(55)   // 竖划高度
        let hW      = u(40)   // 横划宽度

        // L 的左上角对齐点
        let originX = -hW / 2 + strokeW / 2
        let originY = -u(2)

        return ZStack {
            // 竖划（书脊）
            RoundedRectangle(cornerRadius: u(2.5), style: .continuous)
                .fill(Color.white)
                .frame(width: strokeW, height: vH)
                .offset(x: originX, y: originY - (vH - strokeW) / 2)

            // 横划（展开的书页）
            RoundedRectangle(cornerRadius: u(2.5), style: .continuous)
                .fill(Color.white)
                .frame(width: hW, height: strokeW)
                .offset(x: originX + (hW - strokeW) / 2, y: originY + (vH - strokeW) / 2)

            // 书页纹理线（3 条半透明竖线，模拟翻页层次）
            ForEach(0..<3) { i in
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: u(0.9), height: strokeW * 0.7)
                    .offset(
                        x: originX + strokeW + CGFloat(i + 1) * (hW - strokeW) / 4,
                        y: originY + (vH - strokeW) / 2
                    )
            }
        }
    }
}

// MARK: - 导出工具
struct LexoraIconExporter: View {
    @State private var message: String = ""

    var body: some View {
        VStack(spacing: 32) {
            Text("Lexora Icon Preview")
                .font(.headline)
                .foregroundColor(.white)

            LexoraIconView(size: 380)
                .shadow(color: .black.opacity(0.4), radius: 24, y: 8)

            VStack(spacing: 12) {
                Button("保存 1024×1024 到相册") { saveToPhotos() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.48, green: 0.31, blue: 0.83))

                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.10))
    }

    private func saveToPhotos() {
        let icon = LexoraIconView(size: 1024)
        let renderer = ImageRenderer(content: icon)
        renderer.scale = 1.0
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        message = "已保存到相册，可直接拖入 Xcode Assets"
    }
}

#Preview("Icon") {
    LexoraIconView(size: 400)
        .padding(40)
        .background(Color(white: 0.12))
}

#Preview("Exporter") {
    LexoraIconExporter()
}
