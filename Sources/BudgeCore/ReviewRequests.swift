import Foundation

/// An open pull request where someone asked for your review.
public struct ReviewRequest: Equatable, Sendable {
    public let repo: String // "owner/name"
    public let number: Int
    public let title: String
    public let author: String
    public let url: URL

    public var key: String { "\(repo)#\(number)" }

    public init(repo: String, number: Int, title: String, author: String, url: URL) {
        self.repo = repo
        self.number = number
        self.title = title
        self.author = author
        self.url = url
    }
}

public enum ReviewRequests {
    /// Open PRs waiting on your review, asked of you directly or of a team you're on.
    public static let query = "is:pr is:open archived:false review-requested:@me"

    /// Reads the JSON from `gh api search/issues`.
    public static func parse(_ json: Data) throws -> [ReviewRequest] {
        struct Response: Decodable { let items: [Item] }
        struct Item: Decodable {
            struct User: Decodable { let login: String }
            let number: Int
            let title: String
            let htmlUrl: URL
            let repositoryUrl: String
            let user: User
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: json).items.map { item in
            ReviewRequest(repo: item.repositoryUrl.components(separatedBy: "/repos/").last ?? item.repositoryUrl,
                          number: item.number, title: item.title, author: item.user.login, url: item.htmlUrl)
        }
    }

    /// Requests you haven't opened yet.
    public static func unseen(_ current: [ReviewRequest], seen: Set<String>) -> [ReviewRequest] {
        current.filter { !seen.contains($0.key) }
    }

    /// Forgets requests that are no longer waiting, so being asked again later counts as new.
    public static func prune(_ seen: Set<String>, to current: [ReviewRequest]) -> Set<String> {
        seen.intersection(current.map(\.key))
    }
}
