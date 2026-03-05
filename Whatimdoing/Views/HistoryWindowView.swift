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
    let store: ActivityStore
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var collapsedSections: Set<String> = []
    @State private var editingActivityID: UUID?
    @State private var editText = ""
    @State private var activityToDelete: Activity?

    private var filteredActivities: [Activity] {
        store.searchActivities(debouncedSearchText)
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

    // MARK: - Helpers

    private func sectionExpanded(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !collapsedSections.contains(id) },
            set: { isExpanded in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { collapsedSections.remove(id) }
                    else { collapsedSections.insert(id) }
                }
            }
        )
    }

    private func startEditing(_ activity: Activity) {
        editText = activity.text
        editingActivityID = activity.id
    }

    private func commitEdit(_ activity: Activity) {
        store.updateActivityText(activity, newText: editText)
        editingActivityID = nil
        editText = ""
    }

    private func cancelEditing() {
        editingActivityID = nil
        editText = ""
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
                        Section(isExpanded: sectionExpanded(group.id)) {
                            ForEach(group.activities) { activity in
                                ActivityRowView(
                                    activity: activity,
                                    isEditing: editingActivityID == activity.id,
                                    editText: $editText,
                                    onSaveEdit: { commitEdit(activity) },
                                    onCancelEdit: cancelEditing
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        activityToDelete = activity
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        startEditing(activity)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .contextMenu {
                                    Button {
                                        startEditing(activity)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        activityToDelete = activity
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
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
        .alert(
            "Delete Activity",
            isPresented: Binding(
                get: { activityToDelete != nil },
                set: { if !$0 { activityToDelete = nil } }
            ),
            presenting: activityToDelete
        ) { activity in
            Button("Delete", role: .destructive) {
                withAnimation {
                    store.deleteActivity(activity)
                }
            }
            Button("Cancel", role: .cancel) {
                activityToDelete = nil
            }
        } message: { activity in
            Text("Delete \"\(activity.text)\"? This cannot be undone.")
        }
        .task(id: searchText) {
            if searchText.isEmpty {
                debouncedSearchText = ""
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            debouncedSearchText = searchText
        }
        .onChange(of: searchText) {
            if editingActivityID != nil { cancelEditing() }
        }
    }
}

// MARK: - Current Activity Banner

private struct CurrentActivityBanner: View {
    let activity: Activity

    @ScaledMetric(relativeTo: .caption) private var dotSize = 8.0
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: dotSize, height: dotSize)
                .scaleEffect(isPulsing ? 1.4 : 1.0)
                .opacity(isPulsing ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
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
        .onAppear { isPulsing = true }
    }
}

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
    let store: ActivityStore
    @State private var selectedPeriod: StatsPeriod = .today

    var body: some View {
        HStack(spacing: 12) {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(StatsPeriod.allCases) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)

            let stats = store.stats(for: selectedPeriod)
            Text("\(stats.count) \(stats.count == 1 ? "activity" : "activities")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if stats.duration > 0 {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(Formatters.formatDuration(stats.duration))
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
    let isEditing: Bool
    @Binding var editText: String
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void

    @FocusState private var isEditFocused: Bool

    var body: some View {
        if isEditing {
            editingContent
        } else {
            displayContent
        }
    }

    private var editingContent: some View {
        HStack(spacing: 8) {
            TextField("Activity text", text: $editText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .focused($isEditFocused)
                .onSubmit { onSaveEdit() }
                .onExitCommand { onCancelEdit() }

            Button(action: onSaveEdit) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(editText.trimmingCharacters(in: .whitespaces).isEmpty)

            Button(action: onCancelEdit) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
        .onAppear { isEditFocused = true }
    }

    private var displayContent: some View {
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
