import Foundation

/// API 키 보관/조회.
///
/// ⚠️ 보안 주의: MVP 단계에서는 사용자가 설정 화면에서 입력한 키를 UserDefaults 에 저장한다.
/// 실제 배포 시에는 (1) Keychain 저장 또는 (2) 본인 서버를 프록시로 두어
/// 클라이언트에 키를 두지 않는 방식을 권장한다. (앱에 임베드된 키는 추출될 수 있음)
struct APIConfig {
    private static let openAIKeyKey = "config.openai.key"
    private static let anthropicKeyKey = "config.anthropic.key"
    private static let modelKey = "config.claude.model"
    private static let langKey = "config.stt.lang"

    static var openAIKey: String {
        get { UserDefaults.standard.string(forKey: openAIKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: openAIKeyKey) }
    }

    static var anthropicKey: String {
        get { UserDefaults.standard.string(forKey: anthropicKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: anthropicKeyKey) }
    }

    /// 회의록 요약에 쓸 Claude 모델. 필요 시 설정에서 변경.
    static var claudeModel: String {
        get { UserDefaults.standard.string(forKey: modelKey) ?? "claude-sonnet-4-6" }
        set { UserDefaults.standard.set(newValue, forKey: modelKey) }
    }

    /// 받아쓰기 언어 (Whisper)
    static var sttLanguage: String {
        get { UserDefaults.standard.string(forKey: langKey) ?? "ko" }
        set { UserDefaults.standard.set(newValue, forKey: langKey) }
    }

    static var isConfigured: Bool {
        !openAIKey.isEmpty && !anthropicKey.isEmpty
    }
}
