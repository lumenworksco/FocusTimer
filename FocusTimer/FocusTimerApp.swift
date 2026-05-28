import SwiftUI

@main
struct FocusTimerApp: App {
    @StateObject private var viewModel = TimerViewModel()

    init() {
        NotificationManager.shared.requestPermission()
        UpdateChecker.shared.check()
    }

    var body: some Scene {
        Window("FocusTimer", id: "main") {
            MainWindowView()
                .environmentObject(viewModel)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            ContentView()
                .environmentObject(viewModel)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: menuIcon)
                Text(viewModel.formattedTime)
                    .monospacedDigit()
                    .font(.system(size: 13))
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuIcon: String {
        if !viewModel.isRunning && viewModel.progress > 0 {
            return "pause.fill"
        }
        return viewModel.sessionType.sfSymbol
    }
}
