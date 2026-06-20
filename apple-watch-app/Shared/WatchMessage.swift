import Foundation

/// Apple Watch ↔ iPhone 사이에 주고받는 메시지 규약.
/// WatchConnectivity 의 `sendMessage` / `updateApplicationContext` 의 payload 키로 사용한다.
enum WatchMessage {
    /// payload 의 최상위 키
    static let commandKey = "command"
    static let stateKey = "state"
    static let elapsedKey = "elapsed"       // 녹음 경과 시간(초)
    static let titleKey = "title"           // 회의 제목(선택)

    /// 워치 → 폰: 동작 명령
    enum Command: String {
        case start          // 녹음 시작
        case stop           // 녹음 정지 + 회의록 생성 시작
        case requestState   // 현재 상태 알려줘 (앱 켜질 때)
    }

    /// 폰 → 워치: 현재 상태
    enum State: String {
        case idle           // 대기
        case recording      // 녹음 중
        case processing     // 받아쓰기/요약 중
        case done           // 회의록 완성
        case error          // 오류
    }
}
