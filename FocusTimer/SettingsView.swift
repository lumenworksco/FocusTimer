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
                settingRow("Notifications") {
                    Toggle("", isOn: $vm.notificationsEnabled)
                        .labelsHidden()
                        .onChange(of: vm.notificationsEnabled) { enabled in
                            if enabled { NotificationManager.shared.requestPermission() }
                        }
                }
                if vm.notificationsEnabled {
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
                    HStack(spacing: 8) {
                        shortcutBadge("⌃⌥Space")
                        Text("Start / Pause")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        shortcutBadge("⌃⌥S")
                        Text("Skip")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 38)
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

    private func shortcutBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(NSColor.controlColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.1), lineWidth: 1))
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
