import Foundation

// MARK: - Cloudinary 上传（图片 + JSON raw 文件）

enum CloudinaryUploader {

    private static let cloudName    = "dtwjylplt"
    private static let uploadPreset = "QuizAppImage"
    private static let endpoint     = URL(string: "https://api.cloudinary.com/v1_1/dtwjylplt/image/upload")!
    private static let rawEndpoint  = URL(string: "https://api.cloudinary.com/v1_1/dtwjylplt/raw/upload")!

    // MARK: - 上传本地文件，返回公开 HTTPS URL
    static func upload(fileURL: URL) async throws -> String {
        let imageData = try Data(contentsOf: fileURL)
        return try await upload(imageData: imageData)
    }

    static func upload(imageData: Data) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"

        var request        = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody   = buildBody(imageData: imageData, boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown error"
            throw UploadError.serverError(msg)
        }

        let decoded = try JSONDecoder().decode(CloudinaryResponse.self, from: data)
        return decoded.secureUrl
    }

    // MARK: - 上传 JSON 文件，返回公开下载 URL
    static func uploadJSON(_ jsonData: Data, name: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        let safeName = name.replacingOccurrences(of: " ", with: "_")

        var request        = URLRequest(url: rawEndpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody   = buildRawBody(data: jsonData,
                                          filename: "\(safeName).json",
                                          mimeType: "application/json",
                                          boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown error"
            throw UploadError.serverError(msg)
        }
        let decoded = try JSONDecoder().decode(CloudinaryResponse.self, from: data)
        return decoded.secureUrl
    }

    // MARK: - 构建 multipart body
    private static func buildBody(imageData: Data, boundary: String) -> Data {
        var body = Data()

        func append(_ string: String) {
            if let d = string.data(using: .utf8) { body.append(d) }
        }

        // upload_preset 字段
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n")
        append("\(uploadPreset)\r\n")

        // file 字段
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        append("\r\n")

        append("--\(boundary)--\r\n")
        return body
    }

    private static func buildRawBody(data: Data, filename: String,
                                     mimeType: String, boundary: String) -> Data {
        var body = Data()
        func append(_ s: String) { if let d = s.data(using: .utf8) { body.append(d) } }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n")
        append("\(uploadPreset)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")
        return body
    }

    // MARK: - 错误类型
    enum UploadError: LocalizedError {
        case serverError(String)
        var errorDescription: String? {
            switch self {
            case .serverError(let msg): return "上传失败：\(msg)"
            }
        }
    }

    // MARK: - 响应模型
    private struct CloudinaryResponse: Decodable {
        let secureUrl: String
        enum CodingKeys: String, CodingKey {
            case secureUrl = "secure_url"
        }
    }
}
