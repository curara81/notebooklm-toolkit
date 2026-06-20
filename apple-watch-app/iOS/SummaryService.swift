import Foundation

/// Claude API 로 받아쓰기 원문을 구조화된 회의록(Markdown)으로 요약한다.
///
/// ⚠️ 보안: 클라이언트에서 Anthropic API 를 직접 호출하면 키가 노출될 수 있다.
/// 실제 배포에서는 본인 서버를 프록시로 두는 것을 권장.
struct SummaryService {

    enum SummaryError: LocalizedError {
        case missingKey
        case http(Int, String)
        case emptyResult

        var errorDescription: String? {
            switch self {
            case .missingKey: return "Anthropic API 키가 설정되지 않았습니다."
            case .http(let code, let body): return "Claude API 오류(\(code)): \(body)"
            case .emptyResult: return "회의록 생성 결과가 비어 있습니다."
            }
        }
    }

    private let systemPrompt = """
    당신은 전문 회의록 작성자입니다. 음성 받아쓰기 원문(오타·중복·구어체 포함)을 입력받아, \
    깔끔하고 구조화된 한국어 회의록을 Markdown으로 작성합니다.

    반드시 아래 형식을 지키세요:

    # {회의 제목}

    - **일시:** {일시}
    - **참석자:** {참석자, 모르면 '미기재'}

    ## 📌 핵심 요약
    3~5문장으로 회의 전체를 요약.

    ## 🗣 주요 논의 내용
    안건별로 소제목(###)을 만들고, 각 안건의 논의 내용을 불릿으로 정리.

    ## ✅ 결정 사항
    확정된 결정만 번호 매겨 정리. 없으면 '결정된 사항 없음'.

    ## 📋 액션 아이템
    | 담당자 | 할 일 | 기한 |
    |---|---|---|
    담당자·기한이 불명확하면 '미정'으로 표기. 없으면 표 대신 '없음'.

    ## ❓ 미해결/후속 논의 필요
    다음 회의로 넘어간 사항. 없으면 생략 가능.

    규칙:
    - 받아쓰기 오류로 보이는 단어는 문맥상 자연스럽게 보정.
    - 원문에 없는 내용을 지어내지 말 것.
    - 군더더기 없이 간결하게.
    """

    func summarize(transcript: String, title: String, date: Date, attendees: String) async throws -> String {
        let key = APIConfig.anthropicKey
        guard !key.isEmpty else { throw SummaryError.missingKey }

        let df = DateFormatter()
        df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = "yyyy-MM-dd HH:mm"
        let dateText = df.string(from: date)

        let userMessage = """
        회의 제목: \(title)
        일시: \(dateText)
        참석자: \(attendees.isEmpty ? "미기재" : attendees)

        아래는 회의 녹음 받아쓰기 원문입니다. 이를 회의록으로 정리해 주세요.

        === 받아쓰기 원문 시작 ===
        \(transcript)
        === 받아쓰기 원문 끝 ===
        """

        let payload: [String: Any] = [
            "model": APIConfig.claudeModel,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userMessage]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SummaryError.emptyResult }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SummaryError.http(http.statusCode, body)
        }

        // 응답에서 text 블록 추출
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]]
        else { throw SummaryError.emptyResult }

        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw SummaryError.emptyResult }
        return text
    }
}
