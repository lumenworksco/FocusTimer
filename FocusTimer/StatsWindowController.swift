import AppKit
import SwiftUI

final class StatsWindowController {
    static let shared = StatsWindowController()

    private var window: NSWindow?

    private init() {}

    func open() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Stats"
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: StatsView())
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
}
