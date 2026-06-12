import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: TimerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            sectionLabel("Durations", icon: "clock")

            card {
                settingRow("Work session") {
                    Stepper("\(vm.workDuration) min", value: $vm.workDuration, in: 1...90)
                }
                Divider()
                settingRow("Short break") {
                    Stepper("\(vm.shortBreakDuration) min", value: $vm.shortBreakDuration, in: 1...30)
                }
                Divider()
                settingRow("Long break") {
                    Stepper("\(vm.longBreakDuration) min", value: $vm.longBreakDuration, in: 5...60)
                }
            }

            sectionLabel("Behavior", icon: "gearshape")

            card {
                settingRow("Launch at Login") {
                    Toggle("", isOn: $vm.launchAtLogin).labelsHidden()
                }
                Divider()
                settingRow("Sessions before long break") {
                    Stepper("\(vm.sessionsBeforeLongBreak)", value: $vm.sessionsBeforeLongBreak, in: 2...8)
                }
                Divider()
                settingRow("Daily goal") {
                    Stepper("\(vm.dailyGoal) sessions", value: $vm.dailyGoal, in: 1...20)
                }
                Divider()
                settingRow("Auto-advance sessions") {
                    Toggle("", isOn: $vm.autoAdvance).labelsHidden()
                }
                Divider()
                settingRow("Show label in menu bar") {
                    Toggle("", isOn: $vm.showTaskLabelInMenuBar).labelsHidden()
                }
                Divider()
                settingRow("Pause when idle") {
                    Toggle("", isOn: $vm.idleDetectionEnabled).labelsHidden()
                }
                if vm.idleDetectionEnabled {
                    Divider()
                    settingRow("Idle threshold") {
                        Stepper("\(vm.idlePauseThreshold) min", value: $vm.idlePauseThreshold, in: 2...30)
                    }
                }
                Divider()
                settingRow("Notifications") {
                    Toggle("", isOn: $vm.notificationsEnabled)
                        .labelsHidden()
                        .onChange(of: vm.notificationsEnabled) { enabled in
                            if enabled { NotificationManager.shared.requestPermission() }
                        }
                }
                if vm.notificationsEnabled {
                    Divider()
                    settingRow("Weekly digest") {
                        Toggle("", isOn: $vm.weeklyDigestEnabled).labelsHidden()
                    }
                    Divider()
                    settingRow("Sound") {
                        HStack(spacing: 6) {
                            Button { vm.notificationSound.preview() } label: {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundStyle(vm.notificationSound.canPreview ? .secondary : .tertiary)
                            }
                            .buttonStyle(.plain)
                            .disabled(!vm.notificationSound.canPreview)

                            Picker("", selection: $vm.notificationSound) {
                                ForEach(NotificationSound.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 90)
                        }
                    }
                }
            }
            sectionLabel("Shortcuts", icon: "keyboard")

            card {
                settingRow("Global shortcuts") {
                    Toggle("", isOn: $vm.hotkeysEnabled).labelsHidden()
                }
                if vm.hotkeysEnabled {
                    Divider()
                    settingRow("Start / Pause") {
                        KeyRecorder(
                            label: vm.toggleHotkeyLabel,
                            onStartRecording: { HotkeyManager.shared.unregister() },
                            onCancel: { if vm.hotkeysEnabled { HotkeyManager.shared.register() } },
                            onRecord: { code, mods, label in
                                vm.updateToggleHotkey(code: code, mods: mods, label: label)
                            }
                        )
                    }
                    Divider()
                    settingRow("Skip") {
                        KeyRecorder(
                            label: vm.skipHotkeyLabel,
                            onStartRecording: { HotkeyManager.shared.unregister() },
                            onCancel: { if vm.hotkeysEnabled { HotkeyManager.shared.register() } },
                            onRecord: { code, mods, label in
                                vm.updateSkipHotkey(code: code, mods: mods, label: label)
                            }
                        )
                    }
                }
            }

            Divider()

            HStack {
                Text("Version")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: - Subviews

    private func sectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func settingRow<T: View>(_ label: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
    }
}

private struct KeyRecorder: View {
    let label: String
    let onStartRecording: () -> Void
    let onCancel: () -> Void
    let onRecord: (Int, Int, String) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    private static var isAnyRecording = false

    var body: some View {
        Button { toggleRecording() } label: {
            Text(isRecording ? "Press keys…" : label)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isRecording ? Color.accentColor.opacity(0.15) : Color(NSColor.controlColor))
                .foregroundStyle(isRecording ? Color.accentColor : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isRecording ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording(cancelled: true) }
    }

    private func toggleRecording() {
        isRecording ? stopRecording(cancelled: true) : startRecording()
    }

    private func startRecording() {
        guard !KeyRecorder.isAnyRecording else { return }
        isRecording = true
        KeyRecorder.isAnyRecording = true
        onStartRecording()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else { return event }
            if event.keyCode == 53 { // Escape cancels
                self.stopRecording(cancelled: true)
                return nil
            }
            let mods = self.carbonMods(from: event.modifierFlags)
            guard mods != 0 else { return nil }
            let display = self.modifierSymbols(mods) + self.keyLabel(for: event)
            self.onRecord(Int(event.keyCode), mods, display)
            self.stopRecording(cancelled: false)
            return nil
        }
    }

    private func stopRecording(cancelled: Bool) {
        guard isRecording else { return }
        isRecording = false
        KeyRecorder.isAnyRecording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        if cancelled { onCancel() }
    }

    private func carbonMods(from flags: NSEvent.ModifierFlags) -> Int {
        var c = 0
        if flags.contains(.control) { c |= 4096 }
        if flags.contains(.option)  { c |= 2048 }
        if flags.contains(.command) { c |= 256  }
        if flags.contains(.shift)   { c |= 512  }
        return c
    }

    private func modifierSymbols(_ mods: Int) -> String {
        var s = ""
        if mods & 4096 != 0 { s += "⌃" }
        if mods & 2048 != 0 { s += "⌥" }
        if mods & 256  != 0 { s += "⌘" }
        if mods & 512  != 0 { s += "⇧" }
        return s
    }

    private func keyLabel(for event: NSEvent) -> String {
        switch event.keyCode {
        case 49:  return "Space"
        case 36:  return "↩"
        case 48:  return "⇥"
        case 51:  return "⌫"
        case 117: return "⌦"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:  return (event.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }
}
