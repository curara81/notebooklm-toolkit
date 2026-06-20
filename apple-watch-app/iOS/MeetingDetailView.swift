import SwiftUI

struct MeetingDetailView: View {
    let meeting: MeetingRecord
    @State private var showTranscript = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 회의록 본문 (Markdown 렌더링)
                if let attributed = try? AttributedString(
                    markdown: meeting.minutesMarkdown,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    Text(attributed)
                } else {
                    Text(meeting.minutesMarkdown)
                }

                DisclosureGroup("받아쓰기 원문 보기", isExpanded: $showTranscript) {
                    Text(meeting.transcript)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
                .tint(.accentColor)
            }
            .padding()
            .textSelection(.enabled)
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: meeting.minutesMarkdown) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}
