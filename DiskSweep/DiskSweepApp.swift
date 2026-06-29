import SwiftUI

@main
struct DiskSweepApp: App {
    @StateObject private var viewModel = DiskSweepViewModel()

    var body: some Scene {
        WindowGroup("DiskSweep") {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 560, minHeight: 420)
        }
        .windowResizability(.contentMinSize)
    }
}
