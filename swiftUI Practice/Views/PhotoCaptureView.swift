import SwiftUI
import PhotosUI
import Vision

// MARK: - 拍照录题视图

struct PhotoCaptureView: View {
    @EnvironmentObject private var store: QuizStore

    // OCR 识别用图片
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showCamera = false

    // 题目配图（有图题专用）
    @State private var questionImage: UIImage? = nil
    @State private var questionImageItem: PhotosPickerItem? = nil
    @State private var showCameraForQuestionImage = false

    // 题目类型
    @State private var isImageQuestion = false

    // OCR 状态
    @State private var isRecognizing = false
    @State private var recognizedText = ""

    // UI 状态
    @State private var showEditor = false
    @State private var saveSuccess = false
    @State private var showCameraUnavailable = false

    var body: some View {
        ZStack {
            Color.quizBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    questionTypeSection
                    ocrImageSection
                    if let image = selectedImage {
                        imagePreview(image, label: "识别用图片")
                    }
                    if isRecognizing {
                        recognizingIndicator
                    }
                    if !recognizedText.isEmpty && !isRecognizing {
                        recognizedTextSection
                    }
                    if isImageQuestion {
                        questionImageSection
                        if let qImage = questionImage {
                            imagePreview(qImage, label: "题目配图")
                        }
                    }
                    tipSection
                    Spacer(minLength: 40)
                }
                .padding(.top, 16).padding(.bottom, 40)
            }
        }
        .navigationTitle("拍照录题")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // 编辑器
        .sheet(isPresented: $showEditor) {
            QuestionEditorView(
                prefillText: recognizedText,
                questionImage: isImageQuestion ? questionImage : nil
            ) { question in
                store.addQuestion(question)
                saveSuccess = true
                reset()
            }
        }
        // OCR 相机
        .sheet(isPresented: $showCamera) {
            CameraPickerView(image: $selectedImage).ignoresSafeArea()
        }
        // 配图相机
        .sheet(isPresented: $showCameraForQuestionImage) {
            CameraPickerView(image: $questionImage).ignoresSafeArea()
        }
        .alert("相机不可用", isPresented: $showCameraUnavailable) {
            Button("好的") {}
        } message: {
            Text("此设备不支持相机，请使用相册选择图片")
        }
        .overlay {
            if saveSuccess {
                successToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { saveSuccess = false }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: saveSuccess)
        .onChange(of: selectedItem) { _, item in
            Task { await loadImage(from: item, target: \.selectedImage) }
        }
        .onChange(of: questionImageItem) { _, item in
            Task { await loadImage(from: item, target: \.questionImage) }
        }
        .onChange(of: selectedImage) { _, _ in recognizedText = "" }
        .onChange(of: isImageQuestion) { _, _ in
            // 切换类型时清空配图
            questionImage = nil
            questionImageItem = nil
        }
    }

    // MARK: 头部说明
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("通过拍照快速录入题目").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
            Text("OCR 识别文字后可手动编辑，保存到题库")
                .font(.system(size: 14)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
    }

    // MARK: 题目类型切换
    var questionTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("题目类型").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
            HStack(spacing: 12) {
                typeButton(title: "无图题", icon: "text.alignleft", selected: !isImageQuestion) {
                    isImageQuestion = false
                }
                typeButton(title: "有图题", icon: "photo.fill", selected: isImageQuestion) {
                    isImageQuestion = true
                }
            }
            if isImageQuestion {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").font(.system(size: 12)).foregroundColor(Color.quizPurpleLight)
                    Text("需要两张照片：第一张用于识别文字，第二张作为题目配图")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    func typeButton(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(selected ? .white : Color.quizPurpleLight)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(selected ? Color.quizPurple : Color.quizPurple.opacity(0.15))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizPurple.opacity(selected ? 0 : 0.4), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: OCR 识别图片区（第一张照片）
    var ocrImageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(isImageQuestion ? "第一张 · 识别文字" : "选择题目照片")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                if isImageQuestion {
                    Text("用于 OCR 识别题目文字")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            HStack(spacing: 12) {
                cameraButton(label: selectedImage == nil ? "拍照" : "重拍") {
                    openCamera(for: .ocr)
                }
                albumButton(selection: $selectedItem, label: selectedImage == nil ? "相册" : "重选")
            }
            if selectedImage != nil && !isRecognizing {
                Button {
                    if let img = selectedImage { recognizeText(from: img) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "text.viewfinder").font(.system(size: 15))
                        Text("识别文字").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.quizPurple).cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: 题目配图区（第二张照片，有图题专用）
    var questionImageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("第二张 · 题目配图")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Text("随题目一起保存展示")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            HStack(spacing: 12) {
                cameraButton(label: questionImage == nil ? "拍照" : "重拍") {
                    openCamera(for: .questionImage)
                }
                albumButton(selection: $questionImageItem, label: questionImage == nil ? "相册" : "重选")
            }
            if questionImage == nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 11)).foregroundColor(.yellow.opacity(0.8))
                    Text("尚未选择配图，保存后题目将无图片")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.quizCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizPurple.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: 通用按钮组件
    func cameraButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "camera.fill").font(.system(size: 22)).foregroundColor(Color.quizPurpleLight)
                Text(label).font(.system(size: 13, weight: .medium)).foregroundColor(Color.quizPurpleLight)
            }
            .frame(maxWidth: .infinity).frame(height: 80)
            .background(Color.quizCard).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizPurple.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5])))
        }
        .buttonStyle(PlainButtonStyle())
    }

    func albumButton(selection: Binding<PhotosPickerItem?>, label: String) -> some View {
        PhotosPicker(selection: selection, matching: .images) {
            VStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle").font(.system(size: 22)).foregroundColor(Color.quizPurpleLight)
                Text(label).font(.system(size: 13, weight: .medium)).foregroundColor(Color.quizPurpleLight)
            }
            .frame(maxWidth: .infinity).frame(height: 80)
            .background(Color.quizCard).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quizPurple.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5])))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: 图片预览
    func imagePreview(_ image: UIImage, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary).padding(.horizontal, 20)
            Image(uiImage: image)
                .resizable().scaledToFit()
                .frame(maxHeight: 240).cornerRadius(12)
                .padding(.horizontal, 20)
        }
    }

    // MARK: 识别中提示
    var recognizingIndicator: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Color.quizPurpleLight)
            Text("正在识别文字…").font(.system(size: 14)).foregroundColor(.secondary)
        }
        .padding().background(Color.quizCard).cornerRadius(10)
    }

    // MARK: 识别结果
    var recognizedTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别结果").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button { recognizedText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text(recognizedText)
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                .lineSpacing(4).padding(12)
                .background(Color.black.opacity(0.3)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quizBorder, lineWidth: 0.5))

            // 有图题：需要配图才能进入编辑
            if isImageQuestion && questionImage == nil {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle").foregroundColor(.yellow).font(.system(size: 13))
                    Text("请先完成第二张配图拍摄，再编辑保存").font(.system(size: 12)).foregroundColor(.secondary)
                }
            } else {
                Button {
                    showEditor = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil").font(.system(size: 15))
                        Text("编辑并保存题目").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.quizGreen).cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: 使用提示
    var tipSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill").foregroundColor(.yellow).font(.system(size: 13))
                Text("使用提示").font(.system(size: 13, weight: .medium)).foregroundColor(.yellow)
            }
            VStack(alignment: .leading, spacing: 4) {
                tipRow("拍摄题目时保持图片清晰、光线充足")
                tipRow("无图题：一张照片 OCR 识别后编辑保存")
                tipRow("有图题：第一张识别文字，第二张作为题目配图")
                tipRow("OCR 识别完成后请仔细检查选项和正确答案")
            }
        }
        .padding(14).background(Color(red: 0.18, green: 0.18, blue: 0.10)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·").foregroundColor(.secondary)
            Text(text).font(.system(size: 12)).foregroundColor(.secondary)
        }
    }

    // MARK: 成功提示
    var successToast: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(Color.quizGreen)
                Text("题目已保存到题库").font(.system(size: 14, weight: .medium)).foregroundColor(.white)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.quizCard).cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .padding(.top, 60)
            Spacer()
        }
    }

    // MARK: 逻辑方法
    enum CameraTarget { case ocr, questionImage }

    func openCamera(for target: CameraTarget) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailable = true
            return
        }
        switch target {
        case .ocr:           showCamera = true
        case .questionImage: showCameraForQuestionImage = true
        }
    }

    func loadImage(from item: PhotosPickerItem?, target: ReferenceWritableKeyPath<PhotoCaptureView, UIImage?>) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await MainActor.run { self[keyPath: target] = image }
        }
    }

    func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        isRecognizing = true
        recognizedText = ""

        let request = VNRecognizeTextRequest { req, _ in
            let observations = req.results as? [VNRecognizedTextObservation] ?? []
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            DispatchQueue.main.async {
                self.recognizedText = text
                self.isRecognizing = false
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    func reset() {
        selectedItem = nil
        selectedImage = nil
        questionImage = nil
        questionImageItem = nil
        recognizedText = ""
        isImageQuestion = false
    }
}

// MARK: - 题目编辑器

struct QuestionEditorView: View {
    let prefillText: String
    let questionImage: UIImage?
    let onSave: (Question) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var category = ""
    @State private var questionText = ""
    @State private var options = ["", "", "", ""]
    @State private var correctIndex = 0
    @State private var difficulty = 3
    @State private var explanation = ""
    @State private var showValidationError = false

    let builtInCategories = ["地理", "科学", "历史", "数学", "艺术", "体育"]

    init(prefillText: String, questionImage: UIImage? = nil, onSave: @escaping (Question) -> Void) {
        self.prefillText = prefillText
        self.questionImage = questionImage
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.quizBg.ignoresSafeArea()
                Form {
                    // 分类
                    Section("分类") {
                        TextField("输入或选择分类", text: $category)
                            .foregroundColor(.white)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(builtInCategories, id: \.self) { cat in
                                    Button {
                                        category = cat
                                    } label: {
                                        Text(cat)
                                            .font(.system(size: 12))
                                            .foregroundColor(category == cat ? .white : Color.quizPurpleLight)
                                            .padding(.horizontal, 10).padding(.vertical, 5)
                                            .background(category == cat ? Color.quizPurple : Color.quizPurple.opacity(0.2))
                                            .cornerRadius(14)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(Color.quizCard)

                    // 题目
                    Section("题目内容") {
                        TextEditor(text: $questionText)
                            .frame(minHeight: 80)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.quizCard)
                    .onAppear {
                        if questionText.isEmpty { questionText = prefillText }
                    }

                    // 题目配图预览（有图题时显示）
                    if let img = questionImage {
                        Section("题目配图") {
                            Image(uiImage: img)
                                .resizable().scaledToFit()
                                .frame(maxHeight: 200).cornerRadius(8)
                                .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Color.quizCard)
                    }

                    // 选项
                    Section("选项（共 4 个）") {
                        ForEach(0..<4, id: \.self) { i in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(correctIndex == i ? Color.quizGreen.opacity(0.25) : Color.quizBorder)
                                        .frame(width: 28, height: 28)
                                    Text(["A","B","C","D"][i])
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(correctIndex == i ? Color.quizGreen : .secondary)
                                }
                                TextField("选项 \(["A","B","C","D"][i])", text: $options[i])
                                    .foregroundColor(.white)
                                Spacer()
                                if correctIndex == i {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Color.quizGreen)
                                } else {
                                    Button {
                                        correctIndex = i
                                    } label: {
                                        Image(systemName: "circle").foregroundColor(.secondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.quizCard)

                    // 难度
                    Section("难度") {
                        HStack {
                            Text("难度")
                            Spacer()
                            ForEach(1...5, id: \.self) { d in
                                Image(systemName: d <= difficulty ? "star.fill" : "star")
                                    .foregroundColor(d <= difficulty ? .yellow : .secondary)
                                    .onTapGesture { difficulty = d }
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .listRowBackground(Color.quizCard)

                    // 解析（可选）
                    Section("AI 解析（可选）") {
                        TextEditor(text: $explanation)
                            .frame(minHeight: 60)
                            .foregroundColor(.white)
                            .overlay(
                                Group {
                                    if explanation.isEmpty {
                                        Text("填写解析内容（可留空，后期由 AI 补充）")
                                            .foregroundColor(.secondary).font(.system(size: 13)).padding(8)
                                            .allowsHitTesting(false)
                                    }
                                }, alignment: .topLeading
                            )
                    }
                    .listRowBackground(Color.quizCard)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("编辑题目").navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }.foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveQuestion() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.quizPurpleLight)
                }
            }
            .alert("请检查输入", isPresented: $showValidationError) {
                Button("好的") {}
            } message: {
                Text("请填写分类、题目内容，并至少填写 2 个选项后再保存")
            }
        }
        .preferredColorScheme(.dark)
    }

    func saveQuestion() {
        let filledOptions = options.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !category.trimmingCharacters(in: .whitespaces).isEmpty,
              !questionText.trimmingCharacters(in: .whitespaces).isEmpty,
              filledOptions.count >= 2 else {
            showValidationError = true
            return
        }

        // 保存配图到 Documents 目录
        let imageData: QuestionImageData? = questionImage.flatMap { img in
            guard let data = img.jpegData(compressionQuality: 0.8) else { return nil }
            let filename = "question_\(UUID().uuidString).jpg"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            guard (try? data.write(to: url)) != nil else { return nil }
            return QuestionImageData(type: .file, value: url.path)
        }

        let q = Question(
            category: category.trimmingCharacters(in: .whitespaces),
            text: questionText.trimmingCharacters(in: .whitespaces),
            image: imageData,
            options: options.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            correctIndex: min(correctIndex, filledOptions.count - 1),
            difficulty: difficulty,
            explanation: explanation.isEmpty ? nil : explanation,
            source: .photo
        )
        onSave(q)
        dismiss()
    }
}

// MARK: - 相机封装

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    NavigationStack { PhotoCaptureView() }
        .environmentObject(QuizStore())
        .preferredColorScheme(.dark)
}
