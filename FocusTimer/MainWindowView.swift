import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var vm: TimerViewModel
    @ObservedObject private var updater  = UpdateChecker.shared
    @ObservedObject private var updaterW = AutoUpdater.shared
    @State private var glowOpacity: Double = 0.0
    @State private var breakPrompt: String = ""
    @FocusState private var isTaskFieldFocused: Bool

    private static let breakPrompts = [
        "Stand up and stretch for a minute.",
        "Get some water.",
        "Look out a window — give your eyes a rest.",
        "Take 5 slow, deep breaths.",
        "Roll your shoulders back and relax your jaw.",
        "Walk to another room and back.",
        "Close your eyes and rest for 30 seconds.",
        "Do a quick neck stretch — left, right, forward.",
        "Step outside if you can — even for 60 seconds.",
        "Refill your coffee or tea.",
    ]

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
            taskRow
            ringView
            dotsRow
            if vm.sessionType != .work, !breakPrompt.isEmpty {
                Text(breakPrompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
        .overlay(alignment: .top) {
            if case .failed(let msg) = updaterW.phase { errorBanner(msg) }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.sessionType)
        .onAppear {
            if vm.sessionType != .work {
                breakPrompt = MainWindowView.breakPrompts.randomElement() ?? ""
            }
        }
        .onChange(of: vm.sessionType) { type in
            if type != .work {
                breakPrompt = MainWindowView.breakPrompts.randomElement() ?? ""
            }
        }
    }

    // MARK: - Header

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

                Button { StatsWindowController.shared.open() } label: {
                    Image(systemName: "chart.bar").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button { SettingsWindowController.shared.open(viewModel: vm) } label: {
                    Image(systemName: "gearshape").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Task label

    private var taskRow: some View {
        VStack(spacing: 4) {
            TextField("What are you working on?", text: $vm.taskLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .truncationMode(.tail)
                .focused($isTaskFieldFocused)

            if isTaskFieldFocused && !filteredSuggestions.isEmpty {
                taskSuggestionsView
            }
        }
    }

    private var filteredSuggestions: [String] {
        let all = StatsStore.shared.recentLabels(limit: 8)
        let q = vm.taskLabel.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(q) && $0.lowercased() != q.lowercased() }
    }

    private var taskSuggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(Array(filteredSuggestions.prefix(5).enumerated()), id: \.element) { idx, label in
                if idx > 0 { Divider() }
                Button {
                    vm.taskLabel = label
                    isTaskFieldFocused = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }

    // MARK: - Ring

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

    // MARK: - Dots

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

    // MARK: - Controls

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

    // MARK: - Stats

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

    // MARK: - Goal

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

    // MARK: - Banners

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
                }
                .buttonStyle(.plain)

            case .downloading(let p):
                VStack(spacing: 0) {
                    Text("Downloading update… \(Int(p * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    GeometryReader { geo in
                        Capsule().fill(Color.white.opacity(0.35)).frame(height: 3)
                        Capsule().fill(Color.white).frame(width: geo.size.width * p, height: 3)
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
                .background(Color.blue.opacity(0.75))

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

            case .failed:
                EmptyView()
            }
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle")
            Text(msg)
            Spacer()
            Button("Dismiss") { AutoUpdater.shared.phase = .idle }
                .font(.caption2.weight(.semibold))
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.75))
    }

    // MARK: - Helpers

    private var statusLabel: String {
        if vm.isRunning {
            switch vm.taskLabel.trimmingCharacters(in: .whitespaces).lowercased() {
            case "🍅":                  return "🍅 in progress"
            case "coffee", "☕":        return "☕ brewing"
            case "42":                  return "the answer 🌌"
            case "debug", "debugging": return "🐛 squashing bugs"
            default:                    return "in progress"
            }
        }
        if vm.progress > 0 { return "paused" }
        return "ready"
    }
}
