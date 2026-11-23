import BudgeCore
import SwiftUI

/// The avatar plus its speech bubble. Drawn entirely in SwiftUI so it scales and works in dark mode.
struct NudgeView: View {
    let avatar: Avatar
    let prompt: Prompt
    let caption: String
    var onDone: () -> Void = {}
    var onSnooze: () -> Void = {}
    /// Off for still previews, where onAppear never fires.
    var slideIn = true

    @Environment(\.colorScheme) private var scheme
    @State private var arrived = false

    var body: some View {
        let visible = arrived || !slideIn
        HStack(alignment: .bottom, spacing: 2) {
            AvatarView(avatar: avatar)
            bubble.padding(.bottom, 20)
        }
        .padding(24) // room for the shadow inside the transparent window
        .offset(x: visible ? 0 : 60)
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { arrived = true }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(avatar.name) · \(caption)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(prompt.howLong)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(avatar.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(avatar.accent.opacity(scheme == .dark ? 0.25 : 0.15)))
            }
            Text(prompt.text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Done", action: onDone).buttonStyle(Pill(fill: AnyShapeStyle(avatar.accent), text: .white))
                Button("Snooze 10 min", action: onSnooze).buttonStyle(Pill(fill: AnyShapeStyle(.primary.opacity(0.08))))
            }
            .padding(.top, 4)
        }
        .padding(.leading, 22)
        .padding([.trailing, .vertical], 14)
        .frame(width: 270, alignment: .leading)
        .background(BubbleShape().fill(scheme == .dark ? Color(red: 0.17, green: 0.18, blue: 0.20) : .white))
        .shadow(color: .black.opacity(scheme == .dark ? 0.55 : 0.18), radius: 16, y: 6)
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

private struct Pill: ButtonStyle {
    let fill: AnyShapeStyle
    var text: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(text.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(fill))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
