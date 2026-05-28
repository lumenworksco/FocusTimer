import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var vm: TimerViewModel
    @ObservedObject private var updater = UpdateChecker.shared
    @State private var glowOpacity: Double = 0.0

    private var sessionColor: Color {
        switch vm.sessionType {
        case .work:       return .red
        case .shortBreak: return .green
        case .longBreak:  return .teal
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            headerRow
            ringView
            dotsRow
            controlsRow
            Divider()
            statsRow
            goalRow
        }
        .padding(32)
        .frame(width: 360)
        .overlay(alignment: .top) {
            if let ver = updater.availableVersion { updateBanner(ver) }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.sessionType)
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: vm.sessionType.sfSymbol)
                    .foregroundStyle(sessionColor)
                    .id("icon-\(vm.sessionType)")
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                Text(vm.sessionType.rawValue)
                    .font(.title3.weight(.semibold))
                    .id("label-\(vm.sessionType)")
                    .transition(.opacity)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: vm.sessionType)

            Spacer()

            HStack(spacing: 12) {
                Button { SocialWindowController.shared.open() } label: {
                    Image(systemName: "person.2").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button { SettingsWindowController.shared.open(viewModel: vm) } label: {
                    Image(systemName: "gearshape").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 12)
                .frame(width: 240, height: 240)

            Circle()
                .trim(from: 0, to: vm.progress)
                .stroke(sessionColor.opacity(glowOpacity),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round))
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))
                .blur(radius: 8)
                .animation(.linear(duration: 0.9), value: vm.progress)

            Circle()
                .trim(from: 0, to: vm.progress)
                .stroke(sessionColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: vm.progress)

            VStack(spacing: 6) {
                Text(vm.formattedTime)
                    .font(.system(size: 56, weight: .thin, design: .monospaced))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.25, dampingFraction: 0.9), value: vm.formattedTime)

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .id("status-\(statusLabel)")
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: statusLabel)
            }
        }
        .onChange(of: vm.isRunning) { running in
            if running {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.45
                }
            } else {
                withAnimation(.easeOut(duration: 0.4)) { glowOpacity = 0.0 }
            }
        }
    }

    private var dotsRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<vm.sessionsBeforeLongBreak, id: \.self) { i in
                let filled = i < (vm.completedPomodoros % vm.sessionsBeforeLongBreak)
                Circle()
                    .fill(filled ? sessionColor : Color.secondary.opacity(0.25))
                    .frame(width: 10, height: 10)
                    .scaleEffect(filled ? 1.25 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: filled)
            }
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 16) {
            Button("Reset") { vm.reset() }
                .buttonStyle(.bordered)
                .controlSize(.large)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.toggleTimer() }
            } label: {
                Text(vm.isRunning ? "Pause" : "Start")
                    .frame(minWidth: 80)
                    .contentTransition(.interpolate)
            }
            .buttonStyle(.borderedProminent)
            .tint(sessionColor)
            .controlSize(.large)
            .animation(.easeInOut(duration: 0.2), value: sessionColor)

            Button("Skip") { vm.skip() }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }

    private var statsRow: some View {
        HStack {
            statItem("\(vm.completedPomodoros)", "sessions")
            Divider().frame(height: 32)
            statItem("\(StatsStore.shared.todayFocusMinutes)", "min focus")
            Divider().frame(height: 32)
            statItem("\(StatsStore.shared.currentStreak)", "day streak")
        }
        .frame(maxWidth: .infinity)
    }

    private func statItem(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title2.weight(.semibold))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4), value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var goalRow: some View {
        let done    = vm.completedPomodoros
        let goal    = vm.dailyGoal
        let reached = done >= goal

        return VStack(spacing: 6) {
            HStack {
                Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(reached ? .green : sessionColor)
                    .font(.caption)
                Text(reached ? "Goal reached · \(done) sessions" : "\(done) of \(goal) sessions today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: done)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12)).frame(height: 3)
                    Capsule()
                        .fill(reached ? Color.green : sessionColor)
                        .frame(
                            width: min(geo.size.width * CGFloat(done) / CGFloat(max(goal, 1)), geo.size.width),
                            height: 3
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: done)
                }
            }
            .frame(height: 3)
        }
    }

    private func updateBanner(_ ver: String) -> some View {
        Button {
            NSWorkspace.shared.open(URL(string: "https://github.com/lumenworksco/FocusTimer/releases/latest")!)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.down.circle")
                Text("v\(ver) available — download update")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.75))
        }
        .buttonStyle(.plain)
    }

    private var statusLabel: String {
        if vm.isRunning { return "in progress" }
        if vm.progress > 0 { return "paused" }
        return "ready"
    }
}
