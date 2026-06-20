import Foundation

/// OpenAI Whisper API 로 오디오 파일을 받아쓰기(STT) 한다.
struct TranscriptionService {

    enum TranscriptionError: LocalizedError {
        case missingKey
        case fileTooLarge(Int)
        case http(Int, String)
        case emptyResult

        var errorDescription: String? {
            switch self {
            case .missingKey: return "OpenAI API 키가 설정되지 않았습니다."
            case .fileTooLarge(let mb): return "녹음 파일이 너무 큽니다(\(mb)MB). 25MB 이하만 한 번에 처리됩니다. 회의를 나눠 녹음하거나 맥의 nlm-meeting-minutes.sh 를 사용하세요."
            case .http(let code, let body): return "Whisper API 오류(\(code)): \(body)"
            case .emptyResult: return "받아쓰기 결과가 비어 있습니다."
            }
        }
    }

    /// 오디오 파일 → 텍스트
    func transcribe(fileURL: URL, language: String) async throws -> String {
        let key = APIConfig.openAIKey
        guard !key.isEmpty else { throw TranscriptionError.missingKey }

        let data = try Data(contentsOf: fileURL)
        let sizeMB = data.count / 1_000_000
        if data.count > 25_000_000 { throw TranscriptionError.fileTooLarge(sizeMB) }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        // file 파트
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(data)
        body.append("\r\n")
        // 기타 필드
        appendField("model", "whisper-1")
        appendField("language", language)
        appendField("response_format", "text")
        body.append("--\(boundary)--\r\n")

        let (respData, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else { throw TranscriptionError.emptyResult }
        let text = String(data: respData, encoding: .utf8) ?? ""
        guard http.statusCode == 200 else {
            throw TranscriptionError.http(http.statusCode, text)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranscriptionError.emptyResult }
        return trimmed
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}
