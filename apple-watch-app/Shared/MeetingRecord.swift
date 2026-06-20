import Foundation

/// 한 건의 회의 기록. 녹음 → 받아쓰기 → 회의록 까지의 결과를 담는다.
struct MeetingRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var date: Date
    var audioFileName: String          // Documents 디렉토리 기준 파일명
    var transcript: String             // 받아쓰기 원문
    var minutesMarkdown: String        // Claude 가 만든 회의록 (Markdown)
    var durationSeconds: Double

    var displayDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.MM.dd HH:mm"
        return f.string(from: date)
    }

    var durationText: String {
        let m = Int(durationSeconds) / 60
        let s = Int(durationSeconds) % 60
        return String(format: "%d분 %02d초", m, s)
    }
}
