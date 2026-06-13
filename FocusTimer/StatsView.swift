import SwiftUI
import Charts

struct StatsView: View {
    @State private var tab: Tab = .overview
    @State private var metric: Metric = .sessions
    @State private var range: Int = 28

    enum Tab: String, CaseIterable {
        case overview  = "Overview"
        case patterns  = "Patterns"
        case log       = "Session Log"
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
                VStack(spacing: 20) {
                    heatmapSection
                    metricPicker
                    barChart
                }
                .padding(24)
                Divider()
                footerRow
            } else if tab == .patterns {
                patternsView
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

    // MARK: - Heatmap

    private let heatmapWeeks = 16
    private let cellSize: CGFloat = 24
    private let cellGap: CGFloat = 3

    private var heatmapData: [[StatsStore.DayStat?]] { buildHeatmap(weeks: heatmapWeeks) }
    private var heatmapLabels: [String?] { monthLabels(for: heatmapData) }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Month labels row
            HStack(alignment: .top, spacing: cellGap) {
                Color.clear.frame(width: 18)
                ForEach(0..<heatmapData.count, id: \.self) { w in
                    Color.clear
                        .frame(width: cellSize, height: 12)
                        .overlay(alignment: .leading) {
                            if let label = heatmapLabels[w] {
                                Text(label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                        }
                }
            }

            // Grid
            HStack(alignment: .top, spacing: cellGap) {
                // Day-of-week labels
                VStack(alignment: .trailing, spacing: cellGap) {
                    ForEach(0..<7, id: \.self) { d in
                        Text(["M", "", "W", "", "F", "", ""][d])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: cellSize)
                    }
                }

                // Week columns
                ForEach(0..<heatmapData.count, id: \.self) { w in
                    VStack(spacing: cellGap) {
                        ForEach(0..<7, id: \.self) { d in
                            let stat = heatmapData[w][d]
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cellColor(for: stat))
                                .frame(width: cellSize, height: cellSize)
                                .help(cellTooltip(stat))
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 6) {
                Spacer()
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                ForEach([0, 1, 3, 5, 7], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(legendColor(level))
                        .frame(width: 11, height: 11)
                }
                Text("More")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func buildHeatmap(weeks n: Int) -> [[StatsStore.DayStat?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2
        guard let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: today),
              let startDate  = cal.date(byAdding: .weekOfYear, value: -(n - 1), to: thisMonday)
        else { return [] }

        let allDays = StatsStore.shared.history(days: n * 7 + 7)
        var lookup: [String: StatsStore.DayStat] = [:]
        for day in allDays { lookup[DateFormatter.yyyyMMdd.string(from: day.date)] = day }

        var result: [[StatsStore.DayStat?]] = []
        for w in 0..<n {
            var week: [StatsStore.DayStat?] = []
            for d in 0..<7 {
                guard let date = cal.date(byAdding: .day, value: w * 7 + d, to: startDate) else {
                    week.append(nil); continue
                }
                if date > today {
                    week.append(nil)
                } else {
                    let key = DateFormatter.yyyyMMdd.string(from: date)
                    week.append(lookup[key] ?? StatsStore.DayStat(date: date, sessions: 0, focusMinutes: 0))
                }
            }
            result.append(week)
        }
        return result
    }

    private func monthLabels(for weeks: [[StatsStore.DayStat?]]) -> [String?] {
        var labels = [String?]()
        var prevMonth = -1
        var lastLabelIdx = -4
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        for (idx, week) in weeks.enumerated() {
            if let first = week.compactMap({ $0 }).first {
                let m = cal.component(.month, from: first.date)
                if m != prevMonth {
                    prevMonth = m
                    if idx - lastLabelIdx >= 3 {
                        labels.append(fmt.string(from: first.date))
                        lastLabelIdx = idx
                    } else {
                        labels.append(nil)
                    }
                } else {
                    labels.append(nil)
                }
            } else {
                labels.append(nil)
            }
        }
        return labels
    }

    private func cellColor(for stat: StatsStore.DayStat?) -> Color {
        guard let stat = stat else { return .clear }
        switch stat.sessions {
        case 0:      return Color.secondary.opacity(0.1)
        case 1:      return Color.red.opacity(0.3)
        case 2...3:  return Color.red.opacity(0.55)
        case 4...5:  return Color.red.opacity(0.75)
        default:     return Color.red
        }
    }

    private func legendColor(_ level: Int) -> Color {
        switch level {
        case 0:  return Color.secondary.opacity(0.1)
        case 1:  return Color.red.opacity(0.3)
        case 3:  return Color.red.opacity(0.55)
        case 5:  return Color.red.opacity(0.75)
        default: return Color.red
        }
    }

    private func cellTooltip(_ stat: StatsStore.DayStat?) -> String {
        guard let stat = stat else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        let ds = fmt.string(from: stat.date)
        switch stat.sessions {
        case 0:  return "\(ds) · no sessions"
        case 1:  return "\(ds) · 1 session"
        default: return "\(ds) · \(stat.sessions) sessions"
        }
    }

    // MARK: - Patterns (time-of-day)

    private struct HourBucket: Identifiable {
        let hour: Int
        let count: Int
        var id: Int { hour }
    }

    private var hourData: [HourBucket] {
        let entries = StatsStore.shared.recentEntries(days: range)
        var counts = Array(repeating: 0, count: 24)
        let cal = Calendar.current
        for entry in entries { counts[cal.component(.hour, from: entry.timestamp)] += 1 }
        return counts.enumerated().map { HourBucket(hour: $0.offset, count: $0.element) }
    }

    private var peakHour: HourBucket? {
        hourData.filter { $0.count > 0 }.max(by: { $0.count < $1.count })
    }

    private var patternsView: some View {
        VStack(spacing: 0) {
            let entries = StatsStore.shared.recentEntries(days: range)
            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No sessions in this range")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Complete work sessions to see your peak hours.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                VStack(spacing: 20) {
                    if let peak = peakHour {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Peak focus hour")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(hourLabel(peak.hour, style: .full))
                                    .font(.title3.weight(.semibold))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Sessions at peak")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text("\(peak.count)")
                                    .font(.title3.weight(.semibold))
                            }
                        }
                    }

                    Chart(hourData) { bucket in
                        BarMark(
                            x: .value("Hour", bucket.hour),
                            y: .value("Sessions", bucket.count)
                        )
                        .foregroundStyle(
                            bucket.hour == peakHour?.hour
                                ? Color.red
                                : Color.red.opacity(0.4)
                        )
                        .cornerRadius(2)
                    }
                    .chartXAxis {
                        AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21]) { val in
                            if let h = val.as(Int.self) {
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(Color.secondary.opacity(0.2))
                                AxisValueLabel {
                                    Text(hourLabel(h, style: .short))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { val in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                            AxisValueLabel {
                                if let v = val.as(Int.self) {
                                    Text("\(v)").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...(max(hourData.map(\.count).max() ?? 0, 1) + 1))
                    .frame(height: 180)
                    .animation(.easeInOut(duration: 0.3), value: range)
                }
                .padding(24)
            }
            Divider()
            footerRow
        }
    }

    private enum HourLabelStyle { case short, full }
    private func hourLabel(_ hour: Int, style: HourLabelStyle) -> String {
        switch style {
        case .short:
            switch hour {
            case 0:  return "12a"
            case 12: return "12p"
            default: return hour < 12 ? "\(hour)a" : "\(hour - 12)p"
            }
        case .full:
            switch hour {
            case 0:  return "12:00 AM"
            case 12: return "12:00 PM"
            default: return hour < 12 ? "\(hour):00 AM" : "\(hour - 12):00 PM"
            }
        }
    }

    // MARK: - Metric picker

    private var metricPicker: some View {
        Picker("", selection: $metric) {
            ForEach(Metric.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: .infinity)
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
