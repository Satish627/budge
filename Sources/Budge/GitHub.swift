import BudgeCore
import Foundation

/// Asks GitHub for your review requests through the `gh` command you're already signed in to.
/// Budge never sees or stores a GitHub token.
enum GitHub {
    static let gh = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        .first { FileManager.default.isExecutableFile(atPath: $0) }

    struct Failure: LocalizedError {
        let errorDescription: String?
    }

    static func reviewRequests() async throws -> [ReviewRequest] {
        try await Task.detached { try reviewRequestsNow() }.value
    }

    /// Blocks while `gh` runs, so call it off the main thread (or from the command line).
    static func reviewRequestsNow() throws -> [ReviewRequest] {
        guard let gh else { throw Failure(errorDescription: "gh isn't installed") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gh)
        process.arguments = ["api", "-X", "GET", "search/issues",
                             "-f", "q=\(ReviewRequests.query)", "-f", "per_page=30"]
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let json = output.fileHandleForReading.readDataToEndOfFile()
        let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure(errorDescription: message.split(separator: "\n").first.map(String.init) ?? "gh failed")
        }
        return try ReviewRequests.parse(json)
    }
}
