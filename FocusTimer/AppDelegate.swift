import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let viewModel = TimerViewModel()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellable: AnyCancellable?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first { $0.title == "FocusTimer" }?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationManager.shared.requestPermission()
        UpdateChecker.shared.check()
        if viewModel.weeklyDigestEnabled { DigestChecker.shared.start() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(viewModel)
        )

        HotkeyManager.shared.onToggle = { [weak self] in self?.viewModel.toggleTimer() }
        HotkeyManager.shared.onSkip   = { [weak self] in self?.viewModel.skip() }
        if viewModel.hotkeysEnabled { HotkeyManager.shared.register() }

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

        // Optional task label
        if viewModel.showTaskLabelInMenuBar, !viewModel.taskLabel.isEmpty {
            let raw = viewModel.taskLabel
            let truncated = raw.count > 20 ? String(raw.prefix(19)) + "…" : raw
            result.append(NSAttributedString(string: "  " + truncated, attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 11, weight: .regular)
            ]))
        }

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

    @objc private func handleStatusItemClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if let popoverWindow = popover.contentViewController?.view.window {
                popoverWindow.level = .popUpMenu
                popoverWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            }
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        if popover.isShown { popover.performClose(nil) }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: viewModel.isRunning ? "Pause" : "Start",
            action: #selector(menuToggle),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let skipItem = NSMenuItem(title: "Skip", action: #selector(menuSkip), keyEquivalent: "")
        skipItem.target = self
        menu.addItem(skipItem)

        let resetItem = NSMenuItem(title: "Reset", action: #selector(menuReset), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(menuSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit FocusTimer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    @objc private func menuToggle()   { viewModel.toggleTimer() }
    @objc private func menuSkip()     { viewModel.skip() }
    @objc private func menuReset()    { viewModel.reset() }
    @objc private func menuSettings() { SettingsWindowController.shared.open(viewModel: viewModel) }
}
