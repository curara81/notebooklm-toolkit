import SwiftUI

@main
struct MeetingRecorderApp: App {
    @StateObject private var store: MeetingStore
    @StateObject private var viewModel: RecorderViewModel

    init() {
        let store = MeetingStore()
        _store = StateObject(wrappedValue: store)
        _viewModel = StateObject(wrappedValue: RecorderViewModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(viewModel)
        }
    }
}
