import SwiftUI

@main
struct MeetingRecorderWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityProvider()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(connectivity)
        }
    }
}
