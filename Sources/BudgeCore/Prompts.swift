/// What the buddy asks you to do. Movement over "sit up straight":
/// changing position is what the evidence supports, not one correct posture.
public struct Prompt: Equatable, Sendable {
    /// Used to keep variety: the same kind never comes twice in a row.
    public enum Kind: CaseIterable, Hashable, Sendable {
        case neck, upperBody, hands, legs, move, eyes, breath, water
    }

    public let kind: Kind
    public let text: String
    public let howLong: String

    public init(_ kind: Kind, _ text: String, _ howLong: String) {
        self.kind = kind
        self.text = text
        self.howLong = howLong
    }
}

public struct Prompts: Sendable {
    /// Every 4th nudge is about water: about every 2 hours at the default 30 minutes.
    public static let waterEvery = 4

    public static let all: [Prompt] = [
        // Stretches
        Prompt(.upperBody, "Reach both arms up high and hold.", "20 sec"),
        Prompt(.upperBody, "Roll your shoulders back, slowly.", "5 times"),
        Prompt(.neck, "Turn your head slowly left, then right.", "5 times"),
        Prompt(.legs, "Stand and push your hips forward.", "30 sec"),
        Prompt(.neck, "Tilt your ear toward your shoulder, each side.", "15 sec"),
        Prompt(.neck, "Pull your chin straight back.", "5 times"),
        Prompt(.upperBody, "Squeeze your shoulder blades together.", "5 times"),
        Prompt(.upperBody, "Clasp your hands behind you and open your chest.", "20 sec"),
        Prompt(.upperBody, "Sit tall and twist gently to each side.", "10 sec"),
        Prompt(.hands, "Arm out, gently pull your fingers back, each wrist.", "15 sec"),
        Prompt(.hands, "Spread your fingers wide, then make a fist.", "10 times"),
        Prompt(.legs, "Draw circles with your ankles.", "5 each way"),
        Prompt(.legs, "Stand and reach down toward your toes.", "20 sec"),
        Prompt(.legs, "Stretch your calf against a wall, each leg.", "20 sec"),
        // Move
        Prompt(.move, "Stand up and walk to a window.", "2 min"),
        Prompt(.move, "Change how you sit, or stand for a bit.", "now"),
        Prompt(.move, "Take a short walk, even just to another room.", "5 min"),
        // Eyes
        Prompt(.eyes, "Look at something far away.", "20 sec"),
        Prompt(.eyes, "Close your eyes and let them rest.", "20 sec"),
        Prompt(.eyes, "Blink slowly.", "10 times"),
        // Water and breathing
        Prompt(.water, "Go fill up your water.", "1 min"),
        Prompt(.water, "Drink a glass of water.", "now"),
        Prompt(.breath, "Take 5 slow, deep breaths.", "1 min"),
    ]

    static let water = all.filter { $0.kind == .water }
    /// Everything except water, ordered so the same kind never comes twice in a row.
    static let mixed = interleave(all.filter { $0.kind != .water })

    private var shown = 0
    private var index: Int

    /// Starts at a random place in the rotation unless `start` is given.
    public init(start: Int? = nil) {
        index = (start ?? Int.random(in: 0..<Self.mixed.count)) % Self.mixed.count
    }

    public mutating func next() -> Prompt {
        shown += 1
        if shown % Self.waterEvery == 0 {
            return Self.water[(shown / Self.waterEvery - 1) % Self.water.count]
        }
        defer { index = (index + 1) % Self.mixed.count }
        return Self.mixed[index]
    }

    /// Always takes from the kind with the most left that wasn't just used.
    /// Works as long as no kind is more than half the list.
    static func interleave(_ prompts: [Prompt]) -> [Prompt] {
        var groups = Dictionary(grouping: prompts, by: \.kind)
        let rank = { (kind: Prompt.Kind) in Prompt.Kind.allCases.firstIndex(of: kind)! }
        var result: [Prompt] = []
        var last: Prompt.Kind?
        while let kind = groups.filter({ $0.key != last && !$0.value.isEmpty })
            .max(by: { a, b in
                a.value.count != b.value.count ? a.value.count < b.value.count : rank(a.key) > rank(b.key)
            })?.key {
            result.append(groups[kind]!.removeFirst())
            last = kind
        }
        return result
    }
}
