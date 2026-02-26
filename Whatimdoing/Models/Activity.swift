import Foundation
import SwiftData

@Model
class Activity {
    var id: UUID
    var text: String
    var startedAt: Date
    var endedAt: Date?

    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    init(id: UUID = UUID(), text: String, startedAt: Date = Date(), endedAt: Date? = nil) {
        self.id = id
        self.text = text
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
