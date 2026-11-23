import AppKit
import BudgeCore
import SwiftUI

/// "What did you finish today?" with a text box, Save and Not today.
struct LogPromptView: View {
    let avatar: Avatar
    var onSave: (String) -> Void = { _ in }
    var onSkip: () -> Void = {}
    /// For still previews: shows this text instead of a live text box.
    var previewText: String?

    @State private var text = ""

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        AvatarBubble(avatar: avatar, width: 300, slideIn: previewText == nil) {
            BubbleHeader(avatar: avatar, caption: "End of day", chip: "1 min")
            Text("What did you finish today?")
                .font(.system(size: 15, weight: .semibold))
            field
            HStack(spacing: 8) {
                Button("Save") { if !isEmpty { onSave(text) } }
                    .buttonStyle(Pill(accent: avatar.accent))
                    .opacity(isEmpty && previewText == nil ? 0.5 : 1)
                Button("Not today", action: onSkip).buttonStyle(Pill())
            }
            .padding(.top, 4)
        }
    }

    private var field: some View {
        let box = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Group {
            if let previewText {
                Text(previewText).frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
            } else {
                TextField("Fixed the export bug, reviewed 2 PRs…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3, reservesSpace: true)
                    .onSubmit { if !isEmpty { onSave(text) } }
            }
        }
        .font(.system(size: 13))
        .padding(8)
        .background(box.fill(Color.primary.opacity(0.05)))
        .overlay(box.stroke(Color.primary.opacity(0.12)))
    }
}

/// This week's log, one row per day, with a button to copy it for standup.
struct WeekView: View {
    let avatar: Avatar
    let days: [WorkLog.Day]
    var onOpenLog: () -> Void = {}
    var onClose: () -> Void = {}
    var slideIn = true

    @State private var copied = false

    var body: some View {
        AvatarBubble(avatar: avatar, width: 330, slideIn: slideIn) {
            BubbleHeader(avatar: avatar, caption: "Your week", chip: "\(days.count) days")
            Text(days.isEmpty ? "Nothing logged yet this week." : "Here's what you got done.")
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(days, id: \.date) { day in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(day.weekday.prefix(3))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(avatar.accent)
                            .frame(width: 30, alignment: .leading)
                        Text(day.items.joined(separator: " · "))
                            .font(.system(size: 13))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack(spacing: 8) {
                Button(copied ? "Copied" : "Copy for standup") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(WorkLog.summary(days), forType: .string)
                    copied = true
                }
                .buttonStyle(Pill(accent: avatar.accent))
                .disabled(days.isEmpty)
                Button("Open log", action: onOpenLog).buttonStyle(Pill())
                Button("Close", action: onClose).buttonStyle(Pill())
            }
            .padding(.top, 4)
        }
    }
}
