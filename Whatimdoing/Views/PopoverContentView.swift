import SwiftUI

struct PopoverContentView: View {
    let store: ActivityStore
    let onDismiss: () -> Void

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

            ActivityInputBar(
                inputText: $inputText,
                isInputFocused: $isInputFocused,
                onSave: saveActivity,
                onCancel: cancel
            )

            if !filteredSuggestions.isEmpty {
                SuggestionListView(
                    suggestions: filteredSuggestions,
                    onSelect: selectSuggestion
                )
            }

            Divider()

            if let current = store.currentActivity {
                CurrentActivityBadge(activity: current)
            } else {
                Text("No activity set")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Divider()

            HistoryButton(
                isHovering: $isHoveringHistory,
                onTap: {
                    onDismiss()
                    NotificationCenter.default.post(name: .showHistoryWindow, object: nil)
                }
            )
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
}

// MARK: - Activity Input Bar

private struct ActivityInputBar: View {
    @Binding var inputText: String
    let isInputFocused: FocusState<Bool>.Binding
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("e.g., reviewing PR #42", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .focused(isInputFocused)
                .onSubmit { onSave() }

            Button(action: onSave) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Suggestion List

private struct SuggestionListView: View {
    let suggestions: [Activity]
    let onSelect: (Activity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { activity in
                SuggestionRow(activity: activity, onSelect: onSelect)
            }
        }
        .background(.background.opacity(0.6))
        .clipShape(.rect(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct SuggestionRow: View {
    let activity: Activity
    let onSelect: (Activity) -> Void

    var body: some View {
        Button(action: { onSelect(activity) }) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(activity.text)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
                if let duration = activity.duration {
                    Text(Formatters.formatDuration(duration))
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
        .accessibilityLabel(suggestionAccessibilityLabel)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    private var suggestionAccessibilityLabel: String {
        if let duration = activity.duration {
            return "\(activity.text), duration \(Formatters.formatDuration(duration))"
        }
        return activity.text
    }
}

// MARK: - Current Activity Badge

private struct CurrentActivityBadge: View {
    let activity: Activity

    @ScaledMetric(relativeTo: .caption) private var dotSize = 6.0

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: dotSize, height: dotSize)
            Text("Current:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(activity.text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(Formatters.timeAgo(activity.startedAt))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - History Button

private struct HistoryButton: View {
    @Binding var isHovering: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 11))
                Text("View History")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isHovering ? Color.blue.opacity(0.8) : Color.blue)
            .clipShape(.rect(cornerRadius: 6))
            .scaleEffect(isHovering ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.borderless)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
