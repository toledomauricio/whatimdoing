import SwiftUI

struct HistoryWindowView: View {
    @ObservedObject var store: ActivityStore

    private var groupedActivities: [(String, [Activity])] {
        let grouped = Dictionary(grouping: store.activities) { activity in
            dateLabel(for: activity.startedAt)
        }
        let order = store.activities.map { dateLabel(for: $0.startedAt) }
        var seen = Set<String>()
        let uniqueOrder = order.filter { seen.insert($0).inserted }
        return uniqueOrder.compactMap { key in
            guard let items = grouped[key] else { return nil }
            return (key, items)
        }
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

            Divider()

            if store.activities.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No activities yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Start tracking from the menu bar")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
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

            HStack {
                Text("\(store.activities.count) \(store.activities.count == 1 ? "activity" : "activities")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
