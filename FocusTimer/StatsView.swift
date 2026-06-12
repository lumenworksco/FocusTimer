import SwiftUI
import Charts

struct StatsView: View {
    @State private var tab: Tab = .overview
    @State private var metric: Metric = .sessions
    @State private var range: Int = 28

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case log      = "Session Log"
    }

    enum Metric: String, CaseIterable {
        case sessions  = "Sessions"
        case focusTime = "Focus Time"
    }

    private var data: [StatsStore.DayStat] { StatsStore.shared.history(days: range) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabBar
            Divider()
            if tab == .overview {
                summaryRow
                Divider()
                VStack(spacing: 16) {
                    metricPicker
                    barChart
                }
                .padding(24)
                Divider()
                footerRow
            } else {
                logView
            }
        }
        .frame(width: 500)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Stats History")
                .font(.title2.weight(.semibold))
            Spacer()
            Picker("", selection: $range) {
                Text("1 week").tag(7)
                Text("2 weeks").tag(14)
                Text("4 weeks").tag(28)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 100)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        Picker("", selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    // MARK: - Summary

    private var summaryRow: some View {
        HStack(spacing: 0) {
            summaryCard(
                value: "\(data.reduce(0) { $0 + $1.sessions })",
                label: "sessions",
                icon: "timer"
            )
            Divider().frame(height: 44)
            summaryCard(
                value: formatHours(data.reduce(0) { $0 + $1.focusMinutes }),
                label: "focus time",
                icon: "clock"
            )
            Divider().frame(height: 44)
            summaryCard(
                value: "\(StatsStore.shared.currentStreak)",
                label: "day streak",
                icon: "flame"
            )
            Divider().frame(height: 44)
            summaryCard(
                value: bestDay,
                label: "best day",
                icon: "star"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func summaryCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Metric picker

    private var metricPicker: some View {
        Picker("", selection: $metric) {
            ForEach(Metric.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Chart

    private var barChart: some View {
        Chart(data, id: \.date) { day in
            BarMark(
                x: .value("Date", day.date, unit: .day),
                y: .value(metric.rawValue, metricValue(day))
            )
            .foregroundStyle(barColor(day))
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : range == 14 ? 2 : 7)) { val in
                if let d = val.as(Date.self) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        Text(axisLabel(d))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let v = val.as(Int.self) {
                        Text(metric == .sessions ? "\(v)" : "\(v)m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...(maxValue + 1))
        .frame(height: 180)
        .animation(.easeInOut(duration: 0.3), value: metric)
        .animation(.easeInOut(duration: 0.3), value: range)
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack(spacing: 24) {
            footerStat("Avg / active day", avgPerActiveDay)
            footerStat("Active days", "\(data.filter { $0.sessions > 0 }.count) of \(range)")
            footerStat("Total focus", formatHours(data.reduce(0) { $0 + $1.focusMinutes }))
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func footerStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.caption.weight(.semibold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Session Log

    private var logView: some View {
        let groups = logGroups
        return Group {
            if groups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No sessions in this range")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Complete a work session to see your log.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 48)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        ForEach(groups) { group in
                            Text(group.dateLabel)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                                .padding(.bottom, 6)

                            ForEach(group.entries) { entry in
                                logRow(entry)
                                if entry.id != group.entries.last?.id {
                                    Divider().padding(.leading, 24)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: 320)
            }
        }
    }

    private func logRow(_ entry: StatsStore.SessionEntry) -> some View {
        HStack(spacing: 12) {
            Text(timeString(entry.timestamp))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            Text(entry.taskLabel.isEmpty ? "—" : entry.taskLabel)
                .font(.callout)
                .foregroundStyle(entry.taskLabel.isEmpty ? .tertiary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Text("\(entry.durationMinutes)m")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .frame(height: 38)
    }

    private struct DayGroup: Identifiable {
        let date: Date
        let dateLabel: String
        let entries: [StatsStore.SessionEntry]
        var id: Date { date }
    }

    private var logGroups: [DayGroup] {
        let entries = StatsStore.shared.recentEntries(days: range)
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries) { cal.startOfDay(for: $0.timestamp) }
        return grouped.keys.sorted(by: >).map { date in
            DayGroup(
                date: date,
                dateLabel: dayGroupLabel(date),
                entries: (grouped[date] ?? []).sorted { $0.timestamp > $1.timestamp }
            )
        }
    }

    private func dayGroupLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: date)
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none
        return fmt.string(from: date)
    }

    // MARK: - Helpers

    private func metricValue(_ day: StatsStore.DayStat) -> Int {
        metric == .sessions ? day.sessions : day.focusMinutes
    }

    private func barColor(_ day: StatsStore.DayStat) -> Color {
        let base: Color = metric == .sessions ? .red : .blue
        return day.isToday ? base : base.opacity(0.55)
    }

    private var maxValue: Int {
        data.map { metricValue($0) }.max() ?? 1
    }

    private var bestDay: String {
        let best = data.max(by: { $0.sessions < $1.sessions })
        guard let b = best, b.sessions > 0 else { return "—" }
        return "\(b.sessions)"
    }

    private var avgPerActiveDay: String {
        let active = data.filter { $0.sessions > 0 }
        guard !active.isEmpty else { return "—" }
        let avg = Double(active.reduce(0) { $0 + $1.sessions }) / Double(active.count)
        return String(format: "%.1f", avg)
    }

    private func formatHours(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func axisLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        let fmt = DateFormatter()
        fmt.dateFormat = range == 7 ? "EEE" : "MMM d"
        return fmt.string(from: date)
    }
}
