import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var conn: WatchConnectivityProvider

    var body: some View {
        VStack(spacing: 10) {
            Text(statusText)
                .font(.headline)
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.center)

            if conn.state == .recording {
                Text(conn.elapsedText)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(.red)
            }

            Button(action: { conn.toggleRecording() }) {
                ZStack {
                    Circle()
                        .fill(conn.state == .recording ? Color.red : Color.accentColor)
                        .frame(width: 72, height: 72)
                    Image(systemName: conn.state == .recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(conn.state == .processing)
            .opacity(conn.state == .processing ? 0.4 : 1)

            if !conn.reachable {
                Text("아이폰 연결 대기")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var statusText: String {
        switch conn.state {
        case .idle: return "녹음 시작"
        case .recording: return "● 녹음 중"
        case .processing: return "회의록 정리 중…"
        case .done: return "✅ 완성"
        case .error: return "⚠️ 오류"
        }
    }

    private var statusColor: Color {
        switch conn.state {
        case .recording: return .red
        case .done: return .green
        case .error: return .orange
        default: return .primary
        }
    }
}
