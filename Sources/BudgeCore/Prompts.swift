/// What the buddy asks you to do. Movement over "sit up straight":
/// changing position is what the evidence supports, not one correct posture.
public struct Prompt: Equatable, Sendable {
    public let text: String
    public let howLong: String

    public init(_ text: String, _ howLong: String) {
        self.text = text
        self.howLong = howLong
    }
}

public struct Prompts: Sendable {
    public static let all: [Prompt] = [
        Prompt("Stand up and walk to a window.", "2 min"),
        Prompt("Roll your shoulders back, slowly.", "5 times"),
        Prompt("Reach both arms up high and hold.", "20 sec"),
        Prompt("Change how you sit, or stand for a bit.", "now"),
        Prompt("Look at something far away.", "20 sec"),
        Prompt("Go fill up your water.", "1 min"),
        Prompt("Turn your head slowly left, then right.", "5 times"),
        Prompt("Stand and push your hips forward.", "30 sec"),
    ]

    private var index: Int

    public init(start: Int = Int.random(in: 0..<Prompts.all.count)) {
        index = start % Prompts.all.count
    }

    public mutating func next() -> Prompt {
        defer { index = (index + 1) % Prompts.all.count }
        return Prompts.all[index]
    }
}
