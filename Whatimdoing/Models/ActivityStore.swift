import Foundation
import SwiftData

extension Notification.Name {
    static let activityDidChange = Notification.Name("activityDidChange")
}

class ActivityStore: ObservableObject {
    @Published var currentActivity: Activity?
    @Published var activities: [Activity] = []

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
