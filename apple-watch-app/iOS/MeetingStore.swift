import Foundation

/// 완성된 회의록 목록을 디스크(JSON)에 저장/로드한다.
@MainActor
final class MeetingStore: ObservableObject {
    @Published private(set) var meetings: [MeetingRecord] = []

    private let fileURL: URL = {
        AudioRecorder.documentsURL().appendingPathComponent("meetings.json")
    }()

    init() { load() }

    func add(_ record: MeetingRecord) {
        meetings.insert(record, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        // 오디오 파일도 함께 정리
        for index in offsets {
            let url = AudioRecorder.documentsURL().appendingPathComponent(meetings[index].audioFileName)
            try? FileManager.default.removeItem(at: url)
        }
        meetings.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        meetings = (try? JSONDecoder().decode([MeetingRecord].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(meetings) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
