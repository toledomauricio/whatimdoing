import Foundation

extension Notification.Name {
    static let activityDidChange = Notification.Name("activityDidChange")
}

class ActivityStore: ObservableObject {
    @Published var currentActivity: Activity?
    @Published var activities: [Activity] = []

    private let defaults = UserDefaults.standard

    init() {
        load()
    }

    // MARK: - Public

    func startActivity(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // End current activity
        if var current = currentActivity {
            current.endedAt = Date()
            activities.insert(current, at: 0)
        }

        currentActivity = Activity(text: trimmed)
        trimHistory()
        save()
        NotificationCenter.default.post(name: .activityDidChange, object: nil)
    }

    func clearCurrent() {
        if var current = currentActivity {
            current.endedAt = Date()
            activities.insert(current, at: 0)
        }
        currentActivity = nil
        trimHistory()
        save()
        NotificationCenter.default.post(name: .activityDidChange, object: nil)
    }

    func recentActivities(limit: Int = 5) -> [Activity] {
        var seen = Set<String>()
        return activities.filter { seen.insert($0.text).inserted }
            .prefix(limit)
            .map { $0 }
    }

    func clearHistory() {
        activities.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: Constants.currentActivityKey),
           let activity = try? JSONDecoder().decode(Activity.self, from: data) {
            currentActivity = activity
        }

        if let data = defaults.data(forKey: Constants.activityHistoryKey),
           let history = try? JSONDecoder().decode([Activity].self, from: data) {
            activities = history
        }
    }

    private func save() {
        if let current = currentActivity,
           let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: Constants.currentActivityKey)
        } else {
            defaults.removeObject(forKey: Constants.currentActivityKey)
        }

        if let data = try? JSONEncoder().encode(activities) {
            defaults.set(data, forKey: Constants.activityHistoryKey)
        }
    }

    private func trimHistory() {
        if activities.count > Constants.maxHistorySize {
            activities = Array(activities.prefix(Constants.maxHistorySize))
        }
    }
}
