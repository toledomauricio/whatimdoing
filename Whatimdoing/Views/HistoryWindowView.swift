import SwiftUI

struct HistoryWindowView: View {
    @ObservedObject var store: ActivityStore
    @State private var searchText = ""

    private var allActivities: [Activity] {
        return store.activities
    }

    private var filteredActivities: [Activity] {
        let source = allActivities
        guard !searchText.isEmpty else { return source }
        return source.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedActivities: [(String, [Activity])] {
        let source = filteredActivities
        let grouped = Dictionary(grouping: source) { activity in
            dateLabel(for: activity.startedAt)
        }
        let order = source.map { dateLabel(for: $0.startedAt) }
        var seen = Set<String>()
        let uniqueOrder = order.filter { seen.insert($0).inserted }
        return uniqueOrder.compactMap { key in
            guard let items = grouped[key] else { return nil }
            return (key, items)
        }
    }

    private var todayStats: (count: Int, duration: TimeInterval) {
        let calendar = Calendar.current
        let todayActivities = store.activities.filter { calendar.isDateInToday($0.startedAt) }
        let totalDuration = todayActivities.compactMap(\.duration).reduce(0, +)
        if let current = store.currentActivity, calendar.isDateInToday(current.startedAt) {
            let activeDuration = Date().timeIntervalSince(current.startedAt)
            return (todayActivities.count + 1, totalDuration + activeDuration)
        }
        return (todayActivities.count, totalDuration)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let current = store.currentActivity {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text(current.text)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text("Started \(formatTime(current.startedAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.green.opacity(0.08))
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField("Search activities…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.primary.opacity(0.03))

            Divider()

            if filteredActivities.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: searchText.isEmpty ? "clock" : "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "No activities yet" : "No results for \"\(searchText)\"")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    if searchText.isEmpty {
                        Text("Start tracking from the menu bar")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            } else {
                List {
                    ForEach(groupedActivities, id: \.0) { dateLabel, activities in
                        Section {
                            ForEach(activities) { activity in
                                ActivityRowView(activity: activity)
                            }
                        } header: {
                            Text(dateLabel)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack(spacing: 12) {
                let stats = todayStats
                Text("\(store.activities.count) \(store.activities.count == 1 ? "activity" : "activities")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if stats.duration > 0 {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("Today: \(stats.count) tasks, \(formatDuration(stats.duration))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clear History") {
                    store.clearHistory()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.activities.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 420, minHeight: 400)
    }

    private func dateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 1 { return "< 1m" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}

struct ActivityRowView: View {
    let activity: Activity

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.text)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(timeRange)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let duration = activity.duration {
                Text(formatDuration(duration))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.primary.opacity(0.05))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private var timeRange: String {
        let start = formatTime(activity.startedAt)
        if let end = activity.endedAt {
            return "\(start) – \(formatTime(end))"
        }
        return "Started \(start)"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 1 { return "< 1m" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}
