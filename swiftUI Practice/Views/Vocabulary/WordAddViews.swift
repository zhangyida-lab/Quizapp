import SwiftUI
import PhotosUI
import Vision

// MARK: - 手动添加单词
struct ManualAddSheet: View {
    @EnvironmentObject private var vocabStore: VocabularyStore
    @Environment(\.dismiss) private var dismiss

    @State private var input: String = ""
    @State private var preview: Word? = nil
    @State private var toast: String? = nil
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.quizBg.ignoresSafeArea()
                VStack(spacing: 0) {
                    // 输入区
                    HStack(spacing: 12) {
                        TextField("输入英文单词…", text: $input)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focused)
                            .onChange(of: input) { _, v in
                                preview = v.count >= 2 ? vocabStore.lookupInBuiltIn(word: v) : nil
                            }

                        if !input.isEmpty {
                            Button { input = ""; preview = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button("添加") { addWord() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(input.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Color.quizPurpleLight)
                            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(16)
                    .background(Color.quizCard)

                    Divider().background(Color.quizBorder)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // 内置词库预览
                            if let w = preview {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.quizGreen)
                                            .font(.system(size: 13))
                                        Text("在内置词库中找到，添加后自动补全释义")
                                            .font(.system(size: 13))
                                            .foregroundColor(.quizGreen)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text(w.word)
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundColor(.white)
                                            Text(w.partOfSpeech)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.quizPurpleLight)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.quizPurple.opacity(0.2))
                                                .cornerRadius(4)
                                            Text(w.phonetic)
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        ForEach(Array(w.definitions.prefix(2).enumerated()), id: \.offset) { _, def in
                                            Text(def.meaning)
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.quizCard)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            } else if input.count >= 2 {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 13))
                                    Text("未在已启用词库中找到，将以「待补充释义」添加")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            }

                            Spacer()
                        }
                    }
                }

                // Toast
                if let msg = toast {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(20)
                            .padding(.bottom, 40)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("手动添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }.foregroundColor(.secondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { focused = true }
    }

    private func addWord() {
        let w = input.trimmingCharacters(in: .whitespaces)
        guard !w.isEmpty else { return }
        let result = vocabStore.quickAddManual(word: w)
        let msg: String
        switch result {
        case .enriched:  msg = "「\(w)」已添加，释义已从词库补全 ✅"
        case .added:     msg = "「\(w)」已添加，记得补充释义 📝"
        case .duplicate: msg = "「\(w)」已在生词本中 ✅"
        }
        input = ""; preview = nil
        showToast(msg)
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = nil }
        }
    }
}

// MARK: - 截图识词添加
struct ScreenshotAddSheet: View {
    @EnvironmentObject private var vocabStore: VocabularyStore
    @Environment(\.dismiss) private var dismiss

    @State private var photosItem: PhotosPickerItem? = nil
    @State private var isRecognizing = false
    @State private var detectedWords: [String] = []
    @State private var selected: Set<String> = []
    @State private var toast: String? = nil
    @State private var previewImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.quizBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 选图按钮
                    PhotosPicker(selection: $photosItem, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: previewImage == nil ? "photo.on.rectangle.angled" : "arrow.triangle.2.circlepath")
                                .font(.system(size: 16))
                            Text(previewImage == nil ? "选择截图或照片" : "重新选择")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(Color.quizPurpleLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.quizPurple.opacity(0.15))
                    }
                    .onChange(of: photosItem) { _, item in
                        guard let item else { return }
                        Task { await loadAndRecognize(item) }
                    }

                    Divider().background(Color.quizBorder)

                    if isRecognizing {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Color.quizPurpleLight)
                                .scaleEffect(1.3)
                            Text("正在识别文字…")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else if detectedWords.isEmpty && previewImage != nil {
                        Spacer()
                        Text("未识别到英文单词")
                            .foregroundColor(.secondary)
                        Spacer()
                    } else if !detectedWords.isEmpty {
                        // 全选/取消
                        HStack {
                            Text("识别到 \(detectedWords.count) 个单词")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(selected.count == detectedWords.count ? "取消全选" : "全选") {
                                if selected.count == detectedWords.count {
                                    selected.removeAll()
                                } else {
                                    selected = Set(detectedWords)
                                }
                            }
                            .font(.system(size: 13))
                            .foregroundColor(Color.quizPurpleLight)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)

                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                                ForEach(detectedWords, id: \.self) { word in
                                    WordChip(word: word, isSelected: selected.contains(word)) {
                                        if selected.contains(word) { selected.remove(word) }
                                        else { selected.insert(word) }
                                    }
                                }
                            }
                            .padding(16)
                        }

                        Divider().background(Color.quizBorder)

                        Button {
                            addSelected()
                        } label: {
                            Text(selected.isEmpty ? "请选择要添加的单词" : "添加 \(selected.count) 个单词")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(selected.isEmpty ? .secondary : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selected.isEmpty ? Color.secondary.opacity(0.15) : Color.quizPurple)
                        }
                        .disabled(selected.isEmpty)
                    } else {
                        // 初始空状态
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "text.viewfinder")
                                .font(.system(size: 48))
                                .foregroundColor(Color.quizPurple.opacity(0.5))
                            Text("选择含有英文单词的截图\n自动识别并批量添加到生词本")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                }

                // Toast
                if let msg = toast {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(20)
                            .padding(.bottom, 40)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("截图识词")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }.foregroundColor(.secondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: 加载图片并 OCR
    private func loadAndRecognize(_ item: PhotosPickerItem) async {
        isRecognizing = true
        detectedWords = []
        selected = []

        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            isRecognizing = false
            return
        }

        previewImage = uiImage

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "zh-Hans"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
        } catch {
            await MainActor.run { isRecognizing = false }
            return
        }

        let raw = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")

        // 提取英文单词：纯字母，长度 ≥ 2，去重，排序
        let words = raw.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.range(of: #"^[a-zA-Z]{2,}$"#, options: .regularExpression) != nil }
            .map { $0.lowercased() }

        let unique = Array(NSOrderedSet(array: words).array as! [String])
            .sorted()

        await MainActor.run {
            detectedWords = unique
            isRecognizing = false
        }
    }

    // MARK: 批量添加选中单词
    private func addSelected() {
        var added = 0, enriched = 0, dup = 0
        for w in selected {
            switch vocabStore.quickAddManual(word: w) {
            case .added:     added += 1
            case .enriched:  enriched += 1
            case .duplicate: dup += 1
            }
        }
        selected.removeAll()

        var parts: [String] = []
        if enriched > 0 { parts.append("已补全释义 \(enriched) 个") }
        if added > 0    { parts.append("待补充释义 \(added) 个") }
        if dup > 0      { parts.append("已存在 \(dup) 个") }
        showToast("添加完成：" + parts.joined(separator: "，"))
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toast = nil }
        }
    }
}

// MARK: - 单词 Chip（截图识词用）
private struct WordChip: View {
    let word: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(word)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(isSelected ? Color.quizPurple : Color.quizCard)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.quizPurpleLight : Color.quizBorder, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
