import Foundation
import SwiftData

extension Notification.Name {
    static let activityDidChange = Notification.Name("activityDidChange")
    static let showHistoryWindow = Notification.Name("showHistoryWindow")
}

@Observable
@MainActor
final class ActivityStore {
    var currentActivity: Activity?
    var activities: [Activity] = []

    var todayStats: (count: Int, duration: TimeInterval) {
        let calendar = Calendar.current
        let todayActivities = activities.filter { calendar.isDateInToday($0.startedAt) }
        let totalDuration = todayActivities.compactMap(\.duration).reduce(0, +)
        if let current = currentActivity, calendar.isDateInToday(current.startedAt) {
            let activeDuration = Date().timeIntervalSince(current.startedAt)
            return (todayActivities.count + 1, totalDuration + activeDuration)
        }
        return (todayActivities.count, totalDuration)
    }

    private let modelContext: ModelContext
    private let defaults = UserDefaults.standard

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        load()
    }

    func startActivity(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let current = currentActivity {
            current.endedAt = Date()
        }

        let newActivity = Activity(text: trimmed)
        modelContext.insert(newActivity)
        currentActivity = newActivity
        save()
        fetchHistory()
        NotificationCenter.default.post(name: .activityDidChange, object: nil)
    }

    func clearCurrent() {
        if let current = currentActivity {
            current.endedAt = Date()
        }
        currentActivity = nil
        saveCurrent()
        save()
        fetchHistory()
        NotificationCenter.default.post(name: .activityDidChange, object: nil)
    }

    func recentActivities(limit: Int = 5) -> [Activity] {
        var seen = Set<String>()
        return activities.filter { $0.endedAt != nil && seen.insert($0.text).inserted }
            .prefix(limit)
            .map { $0 }
    }

    func clearHistory() {
        do {
            try modelContext.delete(model: Activity.self)
            try modelContext.save()
        } catch {}
        currentActivity = nil
        activities = []
        defaults.removeObject(forKey: Constants.currentActivityKey)
    }

    func deleteActivity(_ activity: Activity) {
        if currentActivity?.id == activity.id {
            currentActivity = nil
            saveCurrent()
        }
        modelContext.delete(activity)
        save()
        fetchHistory()
        NotificationCenter.default.post(name: .activityDidChange, object: nil)
    }

    func updateActivityText(_ activity: Activity, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        activity.text = trimmed
        save()
        fetchHistory()
        if currentActivity?.id == activity.id {
            NotificationCenter.default.post(name: .activityDidChange, object: nil)
        }
    }

    private func load() {
        fetchHistory()
        if let idString = defaults.string(forKey: Constants.currentActivityKey),
           let uuid = UUID(uuidString: idString) {
            currentActivity = activities.first { $0.id == uuid }
        }
    }

    private func fetchHistory() {
        let descriptor = FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        activities = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func save() {
        try? modelContext.save()
        saveCurrent()
    }

    private func saveCurrent() {
        if let current = currentActivity {
            defaults.set(current.id.uuidString, forKey: Constants.currentActivityKey)
        } else {
            defaults.removeObject(forKey: Constants.currentActivityKey)
        }
    }
}
