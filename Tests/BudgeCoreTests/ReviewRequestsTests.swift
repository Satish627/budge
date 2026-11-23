import Foundation
import Testing
@testable import BudgeCore

/// Trimmed-down `gh api search/issues` output, with made-up repos.
private let sample = Data("""
    {"total_count": 2, "items": [
      {"number": 812, "title": "Fix onboarding status", "html_url": "https://github.com/acme/web/pull/812",
       "repository_url": "https://api.github.com/repos/acme/web", "user": {"login": "maria"}, "state": "open"},
      {"number": 44, "title": "Retry failed exports", "html_url": "https://github.com/acme/api/pull/44",
       "repository_url": "https://api.github.com/repos/acme/api", "user": {"login": "jonas"}, "state": "open"}
    ]}
    """.utf8)

@Test func parsesSearchResults() throws {
    let requests = try ReviewRequests.parse(sample)
    #expect(requests.count == 2)
    #expect(requests[0].repo == "acme/web")
    #expect(requests[0].key == "acme/web#812")
    #expect(requests[0].author == "maria")
    #expect(requests[0].url.absoluteString == "https://github.com/acme/web/pull/812")
}

@Test func emptySearchMeansNothingWaiting() throws {
    #expect(try ReviewRequests.parse(Data(#"{"total_count": 0, "items": []}"#.utf8)).isEmpty)
}

@Test func onlyUnopenedRequestsAreNew() throws {
    let requests = try ReviewRequests.parse(sample)
    let new = ReviewRequests.unseen(requests, seen: ["acme/web#812"])
    #expect(new.map(\.key) == ["acme/api#44"])
}

@Test func reviewedRequestsAreForgotten() throws {
    let stillWaiting = try ReviewRequests.parse(sample).filter { $0.number == 44 }
    let seen = ReviewRequests.prune(["acme/web#812", "acme/api#44"], to: stillWaiting)
    #expect(seen == ["acme/api#44"])
}
