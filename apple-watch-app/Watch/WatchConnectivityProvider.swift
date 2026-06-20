import Foundation
import WatchConnectivity

/// 워치 쪽 WatchConnectivity. 버튼 명령을 아이폰으로 보내고, 아이폰의 상태를 받아 UI에 반영한다.
@MainActor
final class WatchConnectivityProvider: NSObject, ObservableObject, WCSessionDelegate {

    @Published var state: WatchMessage.State = .idle
    @Published var elapsed: Double = 0
    @Published var reachable: Bool = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - 명령 전송

    func send(_ command: WatchMessage.Command) {
        let payload: [String: Any] = [WatchMessage.commandKey: command.rawValue]
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: { [weak self] reply in
                self?.apply(reply)
            }, errorHandler: nil)
        } else {
            // 아이폰이 즉시 닿지 않으면 다음 기회에 전달되도록 transfer
            WCSession.default.transferUserInfo(payload)
        }
    }

    func toggleRecording() {
        switch state {
        case .recording: send(.stop)
        default: send(.start)
        }
    }

    // MARK: - 상태 수신

    private func apply(_ payload: [String: Any]) {
        Task { @MainActor in
            if let raw = payload[WatchMessage.stateKey] as? String,
               let s = WatchMessage.State(rawValue: raw) {
                self.state = s
            }
            if let e = payload[WatchMessage.elapsedKey] as? Double {
                self.elapsed = e
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let isReachable = session.isReachable
        Task { @MainActor in
            self.reachable = isReachable
            // 앱이 켜지면 현재 상태 요청
            self.send(.requestState)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in self.reachable = isReachable }
    }

    var elapsedText: String {
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
