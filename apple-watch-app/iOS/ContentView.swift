import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: RecorderViewModel
    @EnvironmentObject var store: MeetingStore
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                recorderCard

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                meetingsList
            }
            .padding(.top)
            .navigationTitle("회의록")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    // MARK: - 녹음 카드

    private var recorderCard: some View {
        VStack(spacing: 12) {
            TextField("회의 제목 (선택)", text: $viewModel.pendingTitle)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.state == .recording || viewModel.state == .processing)

            Text(statusLine)
                .font(.headline)
                .foregroundStyle(statusColor)

            if viewModel.state == .recording {
                Text(viewModel.elapsedText)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
            }

            recordButton
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var recordButton: some View {
        Button {
            switch viewModel.state {
            case .recording: viewModel.stop()
            default: viewModel.start()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.state == .recording ? Color.red : Color.accentColor)
                    .frame(width: 84, height: 84)
                Image(systemName: viewModel.state == .recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.state == .processing)
        .opacity(viewModel.state == .processing ? 0.4 : 1)
    }

    private var statusLine: String {
        switch viewModel.state {
        case .idle: return APIConfig.isConfigured ? "녹음을 시작하세요" : "⚙️ 설정에서 API 키를 입력하세요"
        case .recording: return "● 녹음 중"
        case .processing: return viewModel.statusMessage
        case .done: return "✅ 회의록 완성!"
        case .error: return "⚠️ 오류"
        }
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .recording: return .red
        case .done: return .green
        case .error: return .orange
        default: return .primary
        }
    }

    // MARK: - 회의록 목록

    private var meetingsList: some View {
        List {
            Section("지난 회의록") {
                if store.meetings.isEmpty {
                    Text("아직 회의록이 없습니다.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.meetings) { meeting in
                    NavigationLink(value: meeting) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meeting.title).font(.body).bold()
                            Text("\(meeting.displayDate) · \(meeting.durationText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { store.delete(at: $0) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: MeetingRecord.self) { MeetingDetailView(meeting: $0) }
    }
}
