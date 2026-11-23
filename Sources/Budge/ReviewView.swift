import AppKit
import BudgeCore
import SwiftUI

/// "maria wants your review": the PR (or PRs), each one clickable, plus Open and Later.
struct ReviewView: View {
    let avatar: Avatar
    let requests: [ReviewRequest]
    /// Opens these PRs in your browser.
    var onOpen: ([URL]) -> Void = { _ in }
    var onLater: () -> Void = {}
    var slideIn = true

    var body: some View {
        let single = requests.count == 1
        AvatarBubble(avatar: avatar, width: 300, slideIn: slideIn) {
            BubbleHeader(avatar: avatar, caption: "Review request", chip: single ? "1 PR" : "\(requests.count) PRs")
            Text(single ? "\(requests[0].author) wants your review" : "\(requests.count) PRs want your review")
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(requests.prefix(4), id: \.key) { request in
                    Button { onOpen([request.url]) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(request.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(request.repo.split(separator: "/").last ?? "") #\(request.number) · \(request.author)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RowStyle())
                }
                if requests.count > 4 {
                    Text("+\(requests.count - 4) more").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Button(single ? "Open PR" : "Open all") { onOpen(requests.map(\.url)) }
                    .buttonStyle(Pill(accent: avatar.accent))
                Button("Later", action: onLater).buttonStyle(Pill())
            }
            .padding(.top, 4)
        }
    }
}

/// A PR row that dims while pressed and shows a hand cursor on hover.
private struct RowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .onHover { inside in inside ? NSCursor.pointingHand.push() : NSCursor.pop() }
    }
}
