import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = TimerViewModel()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationManager.shared.requestPermission()
        UpdateChecker.shared.check()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(viewModel)
        )

        cancellable = viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateButton() }
            }

        updateButton()
    }

    private func updateButton() {
        guard let button = statusItem?.button else { return }

        let result = NSMutableAttributedString()

        // Colored dot — only shown when session is active
        if viewModel.isRunning || viewModel.progress > 0 {
            let dotColor = sessionNSColor(opacity: viewModel.isRunning ? 1.0 : 0.45)
            result.append(NSAttributedString(string: "● ", attributes: [
                .foregroundColor: dotColor,
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .baselineOffset: 1.5
            ]))
        }

        // Time
        result.append(NSAttributedString(string: viewModel.formattedTime, attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        ]))

        button.attributedTitle = result
        button.image = nil
    }

    private func sessionNSColor(opacity: Double) -> NSColor {
        let base: NSColor = switch viewModel.sessionType {
        case .work:       .systemRed
        case .shortBreak: .systemGreen
        case .longBreak:  .systemTeal
        }
        return base.withAlphaComponent(opacity)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
