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
            .foregroundStyle(menuBarColor)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuIcon: String {
        if !viewModel.isRunning && viewModel.progress > 0 {
            return "pause.fill"
        }
        return viewModel.sessionType.sfSymbol
    }

    private var menuBarColor: Color {
        guard viewModel.progress > 0 else { return .primary }
        let base: Color = switch viewModel.sessionType {
        case .work:       .red
        case .shortBreak: .green
        case .longBreak:  .teal
        }
        return viewModel.isRunning ? base : base.opacity(0.5)
    }
}
