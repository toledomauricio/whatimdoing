import SwiftUI

// MARK: - Activity Group (Stable Identity for ForEach)

struct ActivityGroup: Identifiable {
    let id: String
    let label: String
    let activities: [Activity]

    init(label: String, activities: [Activity]) {
        self.id = label
        self.label = label
        self.activities = activities
    }
}

// MARK: - History Window View

struct HistoryWindowView: View {
    var store: ActivityStore
    @State private var searchText = ""

    private var filteredActivities: [Activity] {
        guard !searchText.isEmpty else { return store.activities }
        return store.activities.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedActivities: [ActivityGroup] {
        let source = filteredActivities
        let grouped = Dictionary(grouping: source) { activity in
            Formatters.dateLabel(for: activity.startedAt)
        }
        let order = source.map { Formatters.dateLabel(for: $0.startedAt) }
        var seen = Set<String>()
        let uniqueOrder = order.filter { seen.insert($0).inserted }
        return uniqueOrder.compactMap { key in
            guard let items = grouped[key] else { return nil }
            return ActivityGroup(label: key, activities: items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let current = store.currentActivity {
                CurrentActivityBanner(activity: current)
            }

            SearchBar(searchText: $searchText)

            Divider()

            if filteredActivities.isEmpty {
                EmptyStateView(searchText: searchText)
            } else {
                List {
                    ForEach(groupedActivities) { group in
                        Section {
                            ForEach(group.activities) { activity in
                                ActivityRowView(activity: activity)
                            }
                        } header: {
                            Text(group.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            StatsFooter(store: store)
        }
        .frame(minWidth: 420, minHeight: 400)
    }
}

// MARK: - Current Activity Banner

private struct CurrentActivityBanner: View {
    let activity: Activity

    @ScaledMetric(relativeTo: .caption) private var dotSize = 8.0

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: dotSize, height: dotSize)
            Text(activity.text)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer()
            Text("Started \(Formatters.formatTime(activity.startedAt))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.green.opacity(0.08))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Search Bar

private struct SearchBar: View {
    @Binding var searchText: String

    var body: some View {
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
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    let searchText: String

    var body: some View {
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
    }
}

// MARK: - Stats Footer

private struct StatsFooter: View {
    var store: ActivityStore

    var body: some View {
        HStack(spacing: 12) {
            let stats = store.todayStats
            Text("\(store.activities.count) \(store.activities.count == 1 ? "activity" : "activities")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if stats.duration > 0 {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("Today: \(stats.count) tasks, \(Formatters.formatDuration(stats.duration))")
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
}

// MARK: - Activity Row

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
                Text(Formatters.formatDuration(duration))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.primary.opacity(0.05))
                    .clipShape(.capsule)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var timeRange: String {
        let start = Formatters.formatTime(activity.startedAt)
        if let end = activity.endedAt {
            return "\(start) – \(Formatters.formatTime(end))"
        }
        return "Started \(start)"
    }
}
