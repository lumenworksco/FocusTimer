import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: TimerViewModel
    @ObservedObject private var updater  = UpdateChecker.shared
    @ObservedObject private var updaterW = AutoUpdater.shared
    @State private var glowOpacity: Double = 0.2

    private var sessionColor: Color {
        switch vm.sessionType {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .teal
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: vm.sessionType.sfSymbol)
                        .foregroundStyle(sessionColor)
                        .id("icon-\(vm.sessionType)")
                        .transition(.scale(scale: 0.6).combined(with: .opacity))

                    Text(vm.sessionType.rawValue)
                        .font(.headline)
                        .id("label-\(vm.sessionType)")
                        .transition(.opacity)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: vm.sessionType)

                Spacer()

                Button {
                    SocialWindowController.shared.open()
                } label: {
                    Image(systemName: "person.2")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    StatsWindowController.shared.open()
                } label: {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    SettingsWindowController.shared.open(viewModel: vm)
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Progress ring
            ZStack {
                // Track
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                    .frame(width: 180, height: 180)

                // Glow bloom (pulses when running)
                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(
                        sessionColor.opacity(glowOpacity),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 6)
                    .animation(.linear(duration: 0.9), value: vm.progress)

                // Main arc
                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(sessionColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.9), value: vm.progress)

                // Timer + status
                VStack(spacing: 4) {
                    Text(vm.formattedTime)
                        .font(.system(size: 40, weight: .thin, design: .monospaced))
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: vm.formattedTime)

                    Text(statusLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .id("status-\(statusLabel)")
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: statusLabel)
                }
            }
            // Pulse the glow while running
            .onChange(of: vm.isRunning) { running in
                if running {
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                        glowOpacity = 0.45
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.4)) {
                        glowOpacity = 0.0
                    }
                }
            }

            // Pomodoro dots
            HStack(spacing: 10) {
                ForEach(0..<vm.sessionsBeforeLongBreak, id: \.self) { i in
                    let filled = i < (vm.completedPomodoros % vm.sessionsBeforeLongBreak)
                    Circle()
                        .fill(filled ? sessionColor : Color.secondary.opacity(0.25))
                        .frame(width: 8, height: 8)
                        .scaleEffect(filled ? 1.25 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: filled)
                }
            }

            // Controls
            HStack(spacing: 14) {
                Button("Reset") { vm.reset() }
                    .buttonStyle(.bordered)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        vm.toggleTimer()
                    }
                } label: {
                    Text(vm.isRunning ? "Pause" : "Start")
                        .frame(minWidth: 56)
                        .contentTransition(.interpolate)
                }
                .buttonStyle(.borderedProminent)
                .tint(sessionColor)
                .animation(.easeInOut(duration: 0.2), value: sessionColor)

                Button("Skip") { vm.skip() }
                    .buttonStyle(.bordered)
            }

            // Update banner
            if let ver = updater.availableVersion {
                updateBanner(ver)
            }
            if case .failed(let msg) = updaterW.phase {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(msg)
                    Spacer()
                    Button("✕") { AutoUpdater.shared.phase = .idle }.font(.caption2.weight(.bold))
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            Divider()

            // Footer
            goalFooter
        }
        .padding(24)
        .frame(width: 300)
        .animation(.easeInOut(duration: 0.35), value: vm.sessionType)
    }

    private var goalFooter: some View {
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

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 3)
                    Capsule()
                        .fill(reached ? Color.green : sessionColor)
                        .frame(
                            width: goal > 0
                                ? min(geo.size.width * CGFloat(done) / CGFloat(goal), geo.size.width)
                                : 0,
                            height: 3
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: done)
                }
            }
            .frame(height: 3)
        }
    }

    private func updateBanner(_ ver: String) -> some View {
        Group {
            switch updaterW.phase {
            case .idle:
                Button {
                    if let url = updater.downloadURL {
                        AutoUpdater.shared.startUpdate(from: url)
                    } else {
                        NSWorkspace.shared.open(URL(string: "https://github.com/lumenworksco/FocusTimer/releases/latest")!)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle")
                        Text("v\(ver) available — Update Now")
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)

            case .downloading(let p):
                VStack(spacing: 3) {
                    Text("Downloading… \(Int(p * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                    GeometryReader { geo in
                        Capsule().fill(Color.white.opacity(0.35)).frame(height: 3)
                        Capsule().fill(Color.white).frame(width: geo.size.width * p, height: 3)
                    }
                    .frame(height: 3)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            case .installing:
                HStack(spacing: 5) {
                    ProgressView().controlSize(.mini).colorScheme(.dark)
                    Text("Installing…")
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            case .failed:
                EmptyView()
            }
        }
    }

    private var statusLabel: String {
        if vm.isRunning { return "in progress" }
        if vm.progress > 0 { return "paused" }
        return "ready"
    }
}
