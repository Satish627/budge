import Testing
@testable import BudgeCore

/// The first `count` prompts a fresh rotation would show.
private func nudges(_ count: Int, start: Int = 0) -> [Prompt] {
    var prompts = Prompts(start: start)
    return (0..<count).map { _ in prompts.next() }
}

@Test func hasAllTwentyThreePrompts() {
    #expect(Prompts.all.count == 23)
    #expect(Prompts.mixed.count + Prompts.water.count == 23)
}

@Test func everyFourthNudgeIsWater() {
    let shown = nudges(40)
    for (i, prompt) in shown.enumerated() {
        #expect((prompt.kind == .water) == ((i + 1) % Prompts.waterEvery == 0))
    }
}

@Test func sameKindNeverComesTwiceInARow() {
    for start in 0..<Prompts.mixed.count {
        let shown = nudges(60, start: start)
        for (a, b) in zip(shown, shown.dropFirst()) {
            #expect(a.kind != b.kind, "\(a.text) then \(b.text)")
        }
    }
}

@Test func everyPromptShowsUpWithinOneRound() {
    // 21 non-water prompts plus a water one every 4th nudge: 28 nudges.
    let shown = nudges(28)
    #expect(Set(shown.map(\.text)) == Set(Prompts.all.map(\.text)))
}
