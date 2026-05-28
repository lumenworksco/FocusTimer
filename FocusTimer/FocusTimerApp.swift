import SwiftUI

@main
struct FocusTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("FocusTimer", id: "main") {
            MainWindowView()
                .environmentObject(appDelegate.viewModel)
        }
        .windowResizability(.contentSize)
    }
}
