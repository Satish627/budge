import BudgeCore
import SwiftUI

/// A break nudge: what to do, and Done / Snooze.
struct NudgeView: View {
    let avatar: Avatar
    let prompt: Prompt
    let caption: String
    var onDone: () -> Void = {}
    var onSnooze: () -> Void = {}
    /// Off for still previews, where onAppear never fires.
    var slideIn = true

    var body: some View {
        AvatarBubble(avatar: avatar, slideIn: slideIn) {
            BubbleHeader(avatar: avatar, caption: caption, chip: prompt.howLong)
            Text(prompt.text)
                .font(.system(size: 15, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Done", action: onDone).buttonStyle(Pill(accent: avatar.accent))
                Button("Snooze 10 min", action: onSnooze).buttonStyle(Pill())
            }
            .padding(.top, 4)
        }
    }
}

/// The avatar with a speech bubble beside it, sliding in from the right.
/// Drawn entirely in SwiftUI so it scales and works in dark mode.
struct AvatarBubble<Content: View>: View {
    let avatar: Avatar
    var width: CGFloat
    var slideIn: Bool
    let content: Content

    @Environment(\.colorScheme) private var scheme
    @State private var arrived = false

    init(avatar: Avatar, width: CGFloat = 270, slideIn: Bool = true, @ViewBuilder content: () -> Content) {
        self.avatar = avatar
        self.width = width
        self.slideIn = slideIn
        self.content = content()
    }

    var body: some View {
        let visible = arrived || !slideIn
        HStack(alignment: .bottom, spacing: 2) {
            AvatarView(avatar: avatar)
            VStack(alignment: .leading, spacing: 6) { content }
                .padding(.leading, 22)
                .padding([.trailing, .vertical], 14)
                .frame(width: width, alignment: .leading)
                .background(BubbleShape().fill(scheme == .dark ? Color(red: 0.17, green: 0.18, blue: 0.20) : .white))
                .shadow(color: .black.opacity(scheme == .dark ? 0.55 : 0.18), radius: 16, y: 6)
                .padding(.bottom, 20)
        }
        .padding(24) // room for the shadow inside the transparent window
        .offset(x: visible ? 0 : 60)
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { arrived = true }
        }
    }
}

/// "Waddle · 32 min at the keyboard" on the left, a small tinted chip on the right.
struct BubbleHeader: View {
    let avatar: Avatar
    let caption: String
    let chip: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack {
            Text("\(avatar.name) · \(caption)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(chip)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(avatar.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(avatar.accent.opacity(scheme == .dark ? 0.25 : 0.15)))
        }
    }
}

/// A rounded card with a small tail pointing left at the avatar.
private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 8
        var path = Path(roundedRect: CGRect(x: rect.minX + tail, y: rect.minY,
                                            width: rect.width - tail, height: rect.height),
                        cornerRadius: 16, style: .continuous)
        path.move(to: CGPoint(x: rect.minX + tail + 1, y: rect.maxY - 34))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - 20),
                          control: CGPoint(x: rect.minX + tail - 2, y: rect.maxY - 24))
        path.addQuadCurve(to: CGPoint(x: rect.minX + tail + 1, y: rect.maxY - 14),
                          control: CGPoint(x: rect.minX + tail - 2, y: rect.maxY - 16))
        path.closeSubpath()
        return path
    }
}

/// A rounded button: filled with the avatar's color when `accent` is set, light grey otherwise.
struct Pill: ButtonStyle {
    var accent: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(accent == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.white))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(accent.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary.opacity(0.08))))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
