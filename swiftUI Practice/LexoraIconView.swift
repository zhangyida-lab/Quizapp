import SwiftUI

// MARK: - Lexora App Icon
// Preview 中预览效果，或通过 LexoraIconExporter 导出 1024×1024 PNG 到相册

struct LexoraIconView: View {
    var size: CGFloat = 400
    private func u(_ v: CGFloat) -> CGFloat { size * v / 100 }

    var body: some View {
        ZStack {
            background
            ambientGlow
            letterL
            sparkDot
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: u(22.5), style: .continuous))
    }

    // MARK: 深靛蓝 → 紫罗兰渐变背景
    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.07, blue: 0.38),  // 深靛蓝
                    Color(red: 0.35, green: 0.20, blue: 0.68),  // 紫罗兰
                    Color(red: 0.48, green: 0.24, blue: 0.72),  // 亮紫
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )

            // 右上角高光层，增加立体感
            RadialGradient(
                colors: [
                    Color(red: 0.68, green: 0.52, blue: 1.00).opacity(0.40),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.78, y: 0.18),
                startRadius: 0,
                endRadius: u(55)
            )
        }
    }

    // MARK: 中心柔光（让 L 不漂浮）
    private var ambientGlow: some View {
        Ellipse()
            .fill(Color.white.opacity(0.07))
            .frame(width: u(85), height: u(70))
            .blur(radius: u(18))
            .offset(x: -u(4), y: u(4))
    }

    // MARK: 白色粗体字母 L
    private var letterL: some View {
        let sw: CGFloat = u(15.5)   // 笔画宽度
        let vH: CGFloat = u(56)     // 竖划高度
        let hW: CGFloat = u(40)     // 横划宽度
        let r:  CGFloat = u(4.0)    // 圆角

        // L 重心略偏左下，视觉居中
        let cx: CGFloat = -u(5)
        let cy: CGFloat = u(3)

        let vX = cx - (hW - sw) / 2
        let vY = cy - (vH - sw) / 2
        let hX = cx
        let hY = cy + (vH - sw) / 2

        return ZStack {
            // 竖划
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(Color.white)
                .frame(width: sw, height: vH)
                .offset(x: vX, y: vY)
                .shadow(color: Color.white.opacity(0.30), radius: u(5))

            // 横划
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(Color.white)
                .frame(width: hW, height: sw)
                .offset(x: hX, y: hY)
                .shadow(color: Color.white.opacity(0.30), radius: u(5))
        }
    }

    // MARK: 金色光点（灵光一现 / 学习的火花）
    private var sparkDot: some View {
        // 定位在 L 竖划右上角外侧
        let cx: CGFloat = -u(5)
        let vH: CGFloat = u(56)
        let hW: CGFloat = u(40)
        let sw: CGFloat = u(15.5)

        let dotX = cx - (hW - sw) / 2 + sw + u(6)
        let dotY = -u(5) - (vH - sw) / 2 + u(3)

        return ZStack {
            // 外层柔光晕
            Circle()
                .fill(Color(red: 1.00, green: 0.88, blue: 0.42).opacity(0.35))
                .frame(width: u(15), height: u(15))
                .blur(radius: u(4))
                .offset(x: dotX, y: dotY)

            // 内核亮点
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.00, green: 0.96, blue: 0.70),
                            Color(red: 1.00, green: 0.80, blue: 0.28),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: u(4)
                    )
                )
                .frame(width: u(7.5), height: u(7.5))
                .offset(x: dotX, y: dotY)
        }
    }
}

// MARK: - 导出工具（在真机/模拟器运行后点击按钮保存到相册）
struct LexoraIconExporter: View {
    @State private var message: String = ""

    var body: some View {
        VStack(spacing: 32) {
            Text("Lexora Icon Preview")
                .font(.headline)
                .foregroundColor(.white)

            LexoraIconView(size: 360)
                .shadow(color: .black.opacity(0.5), radius: 28, y: 10)

            VStack(spacing: 12) {
                Button("保存 1024×1024 到相册") { saveToPhotos() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.42, green: 0.26, blue: 0.78))

                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.09))
    }

    private func saveToPhotos() {
        let icon = LexoraIconView(size: 1024)
        let renderer = ImageRenderer(content: icon)
        renderer.scale = 1.0
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        message = "已保存到相册\n拖入 Xcode → Assets.xcassets → AppIcon 即可"
    }
}

// MARK: - Preview
#Preview("Icon 400pt") {
    LexoraIconView(size: 400)
        .padding(48)
        .background(Color(white: 0.10))
}

#Preview("Icon Small (60pt)") {
    HStack(spacing: 24) {
        LexoraIconView(size: 60)
        LexoraIconView(size: 40)
        LexoraIconView(size: 29)
        LexoraIconView(size: 20)
    }
    .padding(40)
    .background(Color(white: 0.10))
}

#Preview("Exporter") {
    LexoraIconExporter()
}
