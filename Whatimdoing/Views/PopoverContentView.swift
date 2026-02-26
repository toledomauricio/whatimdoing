import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var store: ActivityStore
    var onDismiss: () -> Void

    @State private var inputText = ""
    @State private var showSuggestions = false
    @State private var isHoveringHistory = false
    @FocusState private var isInputFocused: Bool

    var filteredSuggestions: [Activity] {
        let recent = store.recentActivities(limit: 5)
        guard !inputText.isEmpty else { return recent }
        return recent.filter {
            $0.text.localizedCaseInsensitiveContains(inputText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What are you doing right now?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                TextField("e.g., reviewing PR #42", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .focused($isInputFocused)
                    .onSubmit { saveActivity() }
                    .onChange(of: inputText) { _, newValue in
                        showSuggestions = !newValue.isEmpty
                    }

                Button(action: saveActivity) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)

                Button(action: cancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if !filteredSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredSuggestions) { activity in
                        Button(action: { selectSuggestion(activity) }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(activity.text)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                if let duration = activity.duration {
                                    Text(formatDuration(duration))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .background(Color.primary.opacity(0.00001))
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() }
                            else { NSCursor.pop() }
                        }
                    }
                }
                .background(.background.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }

            Divider()

            if let current = store.currentActivity {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Current:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(current.text)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Text(timeAgo(current.startedAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("No activity set")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button(action: {
                onDismiss()
                NotificationCenter.default.post(name: .showHistoryWindow, object: nil)
            }) {
                HStack {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 11))
                    Text("View History")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isHoveringHistory ? Color.blue.opacity(0.8) : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .scaleEffect(isHoveringHistory ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHoveringHistory)
            }
            .buttonStyle(.borderless)
            .onHover { hovering in
                isHoveringHistory = hovering
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            inputText = store.currentActivity?.text ?? ""
            isInputFocused = true
        }
    }

    private func saveActivity() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.startActivity(trimmed)
        onDismiss()
    }

    private func cancel() { onDismiss() }

    private func selectSuggestion(_ activity: Activity) {
        inputText = activity.text
        saveActivity()
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 1 { return "< 1m" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}
