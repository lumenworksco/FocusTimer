import AppKit
import SwiftUI

final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func open(viewModel: TimerViewModel) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 310),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "FocusTimer Settings"
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.center()
        win.contentView = NSHostingView(rootView: SettingsView(vm: viewModel))
        window = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}
