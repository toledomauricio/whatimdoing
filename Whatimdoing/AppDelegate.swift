import Cocoa
import SwiftUI
import SwiftData

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    var modelContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            modelContainer = try ModelContainer(for: Activity.self)
            let context = ModelContext(modelContainer!)
            let store = ActivityStore(modelContext: context)
            statusBarController = StatusBarController(store: store)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
