import Foundation
import AVFoundation

/// 아이폰 마이크로 회의를 녹음한다.
/// 회의는 길 수 있으므로 용량을 줄이려고 16kHz mono AAC(저비트레이트)로 저장한다.
/// (Whisper API 25MB 한도 안에서 약 25~30분 분량까지 한 파일로 처리 가능. 더 길면 분할 필요)
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private(set) var currentFileURL: URL?
    private(set) var startedAt: Date?

    enum RecorderError: Error { case sessionFailed, recordFailed }

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
        try session.setActive(true)

        let fileName = "meeting_\(Int(Date().timeIntervalSince1970)).m4a"
        let url = Self.documentsURL().appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 24_000,                 // 저비트레이트 → 작은 파일
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.delegate = self
        guard rec.record() else { throw RecorderError.recordFailed }

        recorder = rec
        currentFileURL = url
        startedAt = Date()
        return url
    }

    /// 녹음 정지. (파일 URL, 길이초) 반환.
    @discardableResult
    func stopRecording() -> (url: URL, duration: Double)? {
        guard let rec = recorder, let url = currentFileURL else { return nil }
        let duration = rec.currentTime
        rec.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? duration
        startedAt = nil
        return (url, max(duration, elapsed))
    }

    var isRecording: Bool { recorder?.isRecording ?? false }

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    static func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 마이크 권한 요청
    static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }
}
