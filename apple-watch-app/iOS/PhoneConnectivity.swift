import Foundation
import WatchConnectivity

/// 아이폰 쪽 WatchConnectivity. 워치에서 온 start/stop 명령을 받아 콜백으로 전달하고,
/// 현재 상태를 워치로 다시 보낸다.
final class PhoneConnectivity: NSObject, WCSessionDelegate {

    /// 워치에서 명령이 도착하면 호출 (메인 스레드)
    var onCommand: ((WatchMessage.Command) -> Void)?

    private var lastState: WatchMessage.State = .idle
    private var lastElapsed: Double = 0

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// 현재 상태를 워치로 전송
    func sendState(_ state: WatchMessage.State, elapsed: Double = 0) {
        lastState = state
        lastElapsed = elapsed
        let payload: [String: Any] = [
            WatchMessage.stateKey: state.rawValue,
            WatchMessage.elapsedKey: elapsed
        ]
        // 즉시 전달 시도 + 백그라운드 대비 applicationContext 갱신
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        try? WCSession.default.updateApplicationContext(payload)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        handle(message)
        // 워치가 상태를 요청한 경우 현재 상태로 응답
        replyHandler([
            WatchMessage.stateKey: lastState.rawValue,
            WatchMessage.elapsedKey: lastElapsed
        ])
    }

    private func handle(_ message: [String: Any]) {
        guard
            let raw = message[WatchMessage.commandKey] as? String,
            let command = WatchMessage.Command(rawValue: raw)
        else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onCommand?(command)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()   // 재활성화
    }
}
