import Foundation
import SwiftUI

/// 녹음 → 받아쓰기 → 회의록 생성의 전체 흐름을 조율한다.
/// 워치 명령과 아이폰 화면 버튼 양쪽에서 호출된다.
@MainActor
final class RecorderViewModel: ObservableObject {

    @Published var state: WatchMessage.State = .idle
    @Published var elapsed: TimeInterval = 0
    @Published var statusMessage: String = "대기 중"
    @Published var errorMessage: String?
    @Published var pendingTitle: String = ""

    private let recorder = AudioRecorder()
    private let transcription = TranscriptionService()
    private let summary = SummaryService()
    private let connectivity = PhoneConnectivity()
    let store: MeetingStore

    private var timer: Timer?

    init(store: MeetingStore) {
        self.store = store
        connectivity.onCommand = { [weak self] command in
            Task { @MainActor in self?.handleWatchCommand(command) }
        }
    }

    // MARK: - 워치 명령 처리

    private func handleWatchCommand(_ command: WatchMessage.Command) {
        switch command {
        case .start: start()
        case .stop: stop()
        case .requestState: connectivity.sendState(state, elapsed: elapsed)
        }
    }

    // MARK: - 녹음 제어

    func start() {
        guard state == .idle || state == .done || state == .error else { return }
        AudioRecorder.requestPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.fail("마이크 권한이 필요합니다. 설정 > 개인정보 보호에서 허용하세요.")
                return
            }
            do {
                _ = try self.recorder.startRecording()
                self.errorMessage = nil
                self.setState(.recording)
                self.statusMessage = "녹음 중…"
                self.startTimer()
            } catch {
                self.fail("녹음을 시작하지 못했습니다: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        guard state == .recording else { return }
        stopTimer()
        guard let result = recorder.stopRecording() else {
            fail("녹음 정지에 실패했습니다.")
            return
        }
        setState(.processing)
        statusMessage = "받아쓰기 준비 중…"
        Task { await process(url: result.url, duration: result.duration) }
    }

    // MARK: - 받아쓰기 + 요약 파이프라인

    private func process(url: URL, duration: Double) async {
        guard APIConfig.isConfigured else {
            fail("API 키가 설정되지 않았습니다. 설정 화면에서 OpenAI·Anthropic 키를 입력하세요.")
            return
        }
        let title = pendingTitle.isEmpty ? defaultTitle() : pendingTitle
        let now = Date()
        do {
            statusMessage = "받아쓰기 중… (Whisper)"
            setState(.processing)
            let transcript = try await transcription.transcribe(fileURL: url, language: APIConfig.sttLanguage)

            statusMessage = "회의록 정리 중… (Claude)"
            let minutes = try await summary.summarize(
                transcript: transcript, title: title, date: now, attendees: ""
            )

            let record = MeetingRecord(
                title: title,
                date: now,
                audioFileName: url.lastPathComponent,
                transcript: transcript,
                minutesMarkdown: minutes,
                durationSeconds: duration
            )
            store.add(record)
            pendingTitle = ""
            statusMessage = "회의록 완성!"
            setState(.done)
        } catch {
            fail(error.localizedDescription)
        }
    }

    // MARK: - 상태/타이머 헬퍼

    private func setState(_ newState: WatchMessage.State) {
        state = newState
        connectivity.sendState(newState, elapsed: elapsed)
    }

    private func fail(_ message: String) {
        errorMessage = message
        statusMessage = "오류"
        setState(.error)
    }

    private func startTimer() {
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsed = self.recorder.elapsed
                self.connectivity.sendState(.recording, elapsed: self.elapsed)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func defaultTitle() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 회의"
        return f.string(from: Date())
    }

    var elapsedText: String {
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
