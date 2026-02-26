import Cocoa
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let store: ActivityStore

    init(store: ActivityStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()

        setupStatusItem()
        setupPopover()
        setupObserver()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Whatimdoing")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.font = NSFont.systemFont(ofSize: 13)
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateTitle()
    }

    private func setupPopover() {
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(store: store, onDismiss: { [weak self] in
                self?.popover.performClose(nil)
            })
        )
        popover.behavior = .transient
        popover.animates = true
    }

    private func setupObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(activityDidChange),
            name: .activityDidChange,
            object: nil
        )
    }

    // MARK: - Actions

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        // Recent activities
        let recentActivities = store.recentActivities(limit: 5)
        if !recentActivities.isEmpty {
            let headerItem = NSMenuItem(title: "Recent Activities", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            for activity in recentActivities {
                let item = NSMenuItem(
                    title: TextTruncator.truncateByCharacters(activity.text, maxLength: 40),
                    action: #selector(recentActivitySelected(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = activity.text
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }

        let customItem = NSMenuItem(title: "Set Activity…", action: #selector(setActivityClicked), keyEquivalent: "")
        customItem.target = self
        menu.addItem(customItem)

        if store.currentActivity != nil {
            let clearItem = NSMenuItem(title: "Clear Current", action: #selector(clearCurrentClicked), keyEquivalent: "")
            clearItem.target = self
            menu.addItem(clearItem)
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Whatimdoing", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Reset menu so left-click still triggers popover
        statusItem.menu = nil
    }

    @objc private func recentActivitySelected(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        store.startActivity(text)
    }

    @objc private func setActivityClicked() {
        togglePopover()
    }

    @objc private func clearCurrentClicked() {
        store.clearCurrent()
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }

    @objc private func activityDidChange() {
        updateTitle()
    }

    // MARK: - Title

    private func updateTitle() {
        guard let button = statusItem.button else { return }

        if let activity = store.currentActivity {
            let font = button.font ?? NSFont.systemFont(ofSize: 13)
            button.title = TextTruncator.truncate(activity.text, maxWidth: 200, font: font)
            button.toolTip = activity.text
        } else {
            button.title = "Not set"
            button.toolTip = "Click to set your current activity"
        }
    }
}
