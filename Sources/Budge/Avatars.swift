import AppKit
import SwiftUI

/// The characters you can pick from the menu bar.
enum Avatar: String, CaseIterable, Sendable {
    case waddle, spike, bleep, mochi

    var name: String {
        switch self {
        case .waddle: "Waddle"
        case .spike: "Spike"
        case .bleep: "Bleep"
        case .mochi: "Mochi"
        }
    }

    var tagline: String {
        switch self {
        case .waddle: "A penguin who never skips a walk"
        case .spike: "A cactus who stretches all day"
        case .bleep: "A robot who can't sit still"
        case .mochi: "A squishy rice cake"
        }
    }

    /// Used for the Done button and the time chip, so each character feels like its own.
    var accent: Color {
        switch self {
        case .waddle: Color(red: 0.93, green: 0.48, blue: 0.16)
        case .spike: Color(red: 0.27, green: 0.58, blue: 0.30)
        case .bleep: Color(red: 0.16, green: 0.50, blue: 0.86)
        case .mochi: Color(red: 0.18, green: 0.62, blue: 0.49)
        }
    }
}

extension Avatar {
    /// A small still picture of the character, for the Avatar menu.
    @MainActor
    func menuImage(height: CGFloat = 30) -> NSImage? {
        let renderer = ImageRenderer(content: AvatarView(avatar: self, frozenAt: 0.98).padding(8))
        renderer.scale = 3
        guard let image = renderer.nsImage else { return nil }
        image.size = NSSize(width: height * image.size.width / image.size.height, height: height)
        return image
    }
}

/// Draws the avatar, animated. Every character fits an 84×92 box, standing on the bottom edge.
struct AvatarView: View {
    let avatar: Avatar
    /// Freezes the animation at this moment, for the app icon.
    var frozenAt: Double?

    var body: some View {
        if let frozenAt {
            pose(at: frozenAt)
        } else {
            TimelineView(.animation) { pose(at: $0.date.timeIntervalSinceReferenceDate) }
        }
    }

    private func pose(at t: Double) -> some View {
        ZStack {
            switch avatar {
            case .waddle: Waddle(t: t)
            case .spike: Spike(t: t)
            case .bleep: Bleep(t: t)
            case .mochi: Mochi(t: t)
            }
        }
        .frame(width: 84, height: 92)
    }
}

/// The app icon: Waddle on an icy rounded square, on Apple's 1024 grid (824 artwork).
struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.87, green: 0.95, blue: 1.0),
                                              Color(red: 0.55, green: 0.76, blue: 0.96)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
            // t = 0.98: standing straight, eyes open, flippers mid-flap
            AvatarView(avatar: .waddle, frozenAt: 0.98).scaleEffect(6.8)
        }
        .frame(width: 1024, height: 1024)
    }
}

/// All characters side by side, for the README and for picking one.
struct Lineup: View {
    var body: some View {
        HStack(alignment: .top, spacing: 26) {
            ForEach(Avatar.allCases, id: \.self) { avatar in
                VStack(spacing: 6) {
                    AvatarView(avatar: avatar)
                    Text(avatar.name).font(.system(size: 14, weight: .bold))
                    Text(avatar.tagline)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 104)
                }
            }
        }
        .padding(32)
    }
}

// MARK: - Characters

/// A penguin in a scarf, rocking side to side and flapping.
private struct Waddle: View {
    let t: Double
    private let navy = Color(red: 0.17, green: 0.22, blue: 0.33)
    private let orange = Color(red: 0.97, green: 0.60, blue: 0.20)
    private let hat = Color(red: 0.90, green: 0.30, blue: 0.32)
    private let hatBand = Color(red: 0.76, green: 0.22, blue: 0.26)

    var body: some View {
        let rock = sin(t * 3.2) * 7
        let flap = (sin(t * 6.4) + 1) * 12
        ZStack {
            GroundShadow(width: 44)
            ZStack {
                flipper.rotationEffect(.degrees(18 + flap), anchor: .top).offset(x: -26, y: 2)
                flipper.rotationEffect(.degrees(-18 - flap), anchor: .top).offset(x: 26, y: 2)
                Ellipse().fill(navy).frame(width: 56, height: 70).offset(y: 3)
                Ellipse().fill(.white).frame(width: 42, height: 54).offset(y: 9)
                Eyes(t: t, spacing: 12).offset(y: -9)
                Ellipse().fill(orange).frame(width: 11, height: 6)
                Cheeks(spacing: 24).offset(y: 1)
                HStack(spacing: 8) { foot; foot }.offset(y: 38)
                // bobble hat
                UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 3,
                                       bottomTrailingRadius: 3, topTrailingRadius: 18)
                    .fill(hat).frame(width: 38, height: 18).offset(y: -30)
                Capsule().fill(hatBand).frame(width: 42, height: 7).offset(y: -22)
                Circle().fill(.white).frame(width: 10, height: 10).offset(y: -41)
            }
            .rotationEffect(.degrees(rock), anchor: .bottom)
        }
    }

    private var flipper: some View { Capsule().fill(navy).frame(width: 12, height: 30) }
    private var foot: some View { Ellipse().fill(orange).frame(width: 15, height: 7) }
}

/// A potted cactus with a flower, pumping its arms one after the other.
private struct Spike: View {
    let t: Double
    private let green = Color(red: 0.40, green: 0.72, blue: 0.42)
    private let ridge = Color(red: 0.25, green: 0.52, blue: 0.28)
    private let clay = Color(red: 0.86, green: 0.47, blue: 0.32)
    private let rim = Color(red: 0.76, green: 0.39, blue: 0.26)

    var body: some View {
        let sway = sin(t * 1.8) * 4
        let left = 16 + sin(t * 2.4) * 6
        let right = 16 - sin(t * 2.4) * 6
        ZStack {
            GroundShadow(width: 42)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 30, y: 52))
                    p.addLine(to: CGPoint(x: 17, y: 52))
                    p.addLine(to: CGPoint(x: 17, y: 52 - left))
                    p.move(to: CGPoint(x: 54, y: 46))
                    p.addLine(to: CGPoint(x: 67, y: 46))
                    p.addLine(to: CGPoint(x: 67, y: 46 - right))
                }
                .stroke(green, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                Capsule().fill(green).frame(width: 38, height: 62).offset(y: -5)
                HStack(spacing: 12) {
                    Capsule().fill(ridge.opacity(0.35)).frame(width: 2.5, height: 18)
                    Capsule().fill(ridge.opacity(0.35)).frame(width: 2.5, height: 18)
                }
                .offset(y: 15)
                flower.offset(x: 7, y: -36)
                Eyes(t: t, spacing: 10).offset(y: -12)
                Cheeks(spacing: 20).offset(y: -2)
                Smile(width: 10).offset(y: 1)
            }
            .rotationEffect(.degrees(sway), anchor: .bottom)
            Trapezoid(inset: 5).fill(clay).frame(width: 40, height: 15).offset(y: 36)
            RoundedRectangle(cornerRadius: 3).fill(rim).frame(width: 46, height: 8).offset(y: 28)
        }
    }

    private var flower: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(Color(red: 1.0, green: 0.55, blue: 0.70))
                    .frame(width: 8, height: 8)
                    .offset(y: -4)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle().fill(Color(red: 1.0, green: 0.85, blue: 0.35)).frame(width: 5, height: 5)
        }
    }
}

/// A hovering robot with an antenna that pulses and arms that wave.
private struct Bleep: View {
    let t: Double
    private let metal = Color(red: 0.88, green: 0.90, blue: 0.93)
    private let metalDark = Color(red: 0.64, green: 0.68, blue: 0.75)
    private let screen = Color(red: 0.10, green: 0.13, blue: 0.19)
    private let led = Color(red: 0.35, green: 0.90, blue: 0.95)

    var body: some View {
        let hover = sin(t * 2.4) * 3
        let wave = sin(t * 2.0) * 16
        let pulse = 0.55 + 0.45 * (sin(t * 5) + 1) / 2
        ZStack {
            GroundShadow(width: 38 - hover * 2)
            ZStack {
                arm(-35 - wave).offset(x: -29, y: -6)
                arm(35 + wave).offset(x: 29, y: -6)
                Capsule().fill(metalDark).frame(width: 3, height: 12).offset(y: -36)
                Circle()
                    .fill(Color(red: 1.0, green: 0.42, blue: 0.40).opacity(pulse))
                    .frame(width: 9, height: 9)
                    .offset(y: -42)
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(LinearGradient(colors: [metal, metalDark], startPoint: .top, endPoint: .bottom))
                    .frame(width: 60, height: 56)
                    .offset(y: -4)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(screen)
                    .frame(width: 46, height: 30)
                    .offset(y: -8)
                Eyes(t: t, spacing: 12, color: led).offset(y: -11)
                Smile(width: 10, color: led).offset(y: -1)
                Ellipse().fill(led.opacity(0.4 * pulse)).frame(width: 22, height: 7).offset(y: 29)
            }
            .offset(y: hover)
        }
    }

    private func arm(_ degrees: Double) -> some View {
        VStack(spacing: -3) {
            Circle().fill(metalDark).frame(width: 11, height: 11)
            Capsule().fill(metalDark).frame(width: 8, height: 22)
        }
        .rotationEffect(.degrees(degrees), anchor: .bottom)
    }
}

/// A soft mint blob that bobs and reaches up.
private struct Mochi: View {
    let t: Double
    private let light = Color(red: 0.62, green: 0.91, blue: 0.80)
    private let mid = Color(red: 0.33, green: 0.77, blue: 0.63)
    private let deep = Color(red: 0.18, green: 0.62, blue: 0.49)

    var body: some View {
        let bob = sin(t * 2.2) * 2.5
        let stretch = sin(t * 1.6) * 14
        ZStack {
            GroundShadow(width: 48 - bob * 2)
            ZStack {
                arm(-40 - stretch).offset(x: -26, y: -12)
                arm(40 + stretch).offset(x: 26, y: -12)
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(LinearGradient(colors: [light, mid], startPoint: .top, endPoint: .bottom))
                    .frame(width: 60, height: 64)
                Ellipse()
                    .fill(.white.opacity(0.35))
                    .frame(width: 16, height: 9)
                    .rotationEffect(.degrees(-20))
                    .offset(x: -14, y: -20)
                Eyes(t: t).offset(y: -5)
                Cheeks().offset(y: 5)
                Smile().offset(y: 8)
            }
            .offset(y: 6 + bob)
        }
    }

    private func arm(_ degrees: Double) -> some View {
        Capsule().fill(deep).frame(width: 10, height: 30).rotationEffect(.degrees(degrees), anchor: .bottom)
    }
}

// MARK: - Shared parts

private let ink = Color(red: 0.11, green: 0.14, blue: 0.18)

private struct Eyes: View {
    let t: Double
    var spacing: CGFloat = 14
    var color: Color = ink

    var body: some View {
        let blink = t.truncatingRemainder(dividingBy: 4.2) < 0.14
        HStack(spacing: spacing) {
            Capsule().frame(width: 6.5, height: blink ? 1.5 : 10)
            Capsule().frame(width: 6.5, height: blink ? 1.5 : 10)
        }
        .foregroundStyle(color)
    }
}

private struct Smile: View {
    var width: CGFloat = 12
    var color: Color = ink

    var body: some View {
        Path { p in
            p.move(to: .zero)
            p.addQuadCurve(to: CGPoint(x: width, y: 0), control: CGPoint(x: width / 2, y: width * 0.58))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        .frame(width: width, height: width / 2)
    }
}

private struct Cheeks: View {
    var spacing: CGFloat = 28

    var body: some View {
        HStack(spacing: spacing) {
            Ellipse().frame(width: 9, height: 5)
            Ellipse().frame(width: 9, height: 5)
        }
        .foregroundStyle(Color(red: 1.0, green: 0.52, blue: 0.60).opacity(0.55))
    }
}

private struct GroundShadow: View {
    let width: CGFloat

    var body: some View {
        Ellipse().fill(.black.opacity(0.13)).frame(width: width, height: 8).offset(y: 42)
    }
}

private struct Trapezoid: Shape {
    let inset: CGFloat

    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - inset, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + inset, y: r.maxY))
            p.closeSubpath()
        }
    }
}
