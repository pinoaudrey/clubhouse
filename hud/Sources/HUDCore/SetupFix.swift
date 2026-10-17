import Foundation

/// Clicking a setup problem opens a new Claude Code session in `~/.agents`
/// with a prompt for that problem in the composer, addressed to Raya. Selecting
/// several problems and asking for one session puts all of them in one prompt.
///
/// The link only fills the composer: the session starts when you press
/// Enter, so a stray click costs nothing. One session ends as one branch and
/// one PR, whether it carries one problem or several.
///
/// Pure text and URL assembly, so tests check the link without opening it.
public enum SetupFix {

    /// One problem and the section that reported it: the unit a row shows and
    /// the unit a selection holds.
    public struct Item: Equatable {
        public let section: SetupSectionResult
        public let problem: SetupResult

        public init(section: SetupSectionResult, problem: SetupResult) {
            self.section = section
            self.problem = problem
        }
    }

    /// The Claude app cuts `q` at this many characters.
    static let promptLimit = 14_336

    /// The rules a fix session needs on top of the clipboard's.
    /// The app starts a session in a worktree of `~/.agents`, and the scripts
    /// in `bin/` default to the shared checkout.
    static let sessionRules = [
        "This session can run in a git worktree of ~/.agents. Set AGENTS_DIR to the worktree when you run bin/capture.sh, so the capture lands on your branch.",
    ]

    /// The extra rule when one session carries several problems.
    static let batchRule = "Fix every problem above in this one session, on one branch with one PR."

    public static func prompt(items: [Item], generatedAt: Date?, now: Date = Date()) -> String {
        let ask = items.count == 1
            ? "Please fix this problem in my ~/.agents setup."
            : "Please fix these \(items.count) problems in my ~/.agents setup."
        var lines = [SetupClipboard.seatCall, ask]
        lines.append("")
        lines.append("Reported by bin/check-setup.sh, \(SetupClipboard.stamp(generatedAt ?? now)).")
        for (index, item) in items.enumerated() {
            lines.append("")
            lines.append(contentsOf: SetupClipboard.problemLines(
                number: index + 1, section: item.section, problem: item.problem))
        }
        lines.append("")
        lines.append("Rules from ~/.agents/AGENTS.md that apply here:")
        var rules = SetupClipboard.rules + sessionRules
        if items.count > 1 { rules.append(batchRule) }
        lines.append(contentsOf: rules.map { "- \($0)" })
        return lines.joined(separator: "\n") + "\n"
    }

    public static func prompt(
        section: SetupSectionResult,
        problem: SetupResult,
        generatedAt: Date?,
        now: Date = Date()
    ) -> String {
        prompt(items: [Item(section: section, problem: problem)], generatedAt: generatedAt, now: now)
    }

    /// `claude://code/new?q=…&folder=…`, the link the Claude app's own dock
    /// menu uses for a new Code session in a folder. Nil when the prompt is
    /// too long for the app to take whole.
    public static func link(prompt: String, folder: String) -> URL? {
        guard prompt.count <= promptLimit else { return nil }
        return URL(string: "claude://code/new?q=\(encode(prompt))&folder=\(encode(folder))")
    }

    /// Nil for an empty selection, and for one whose prompt is too long for the
    /// app to take whole.
    public static func link(
        items: [Item],
        generatedAt: Date?,
        now: Date = Date(),
        home: String = NSHomeDirectory()
    ) -> URL? {
        guard !items.isEmpty else { return nil }
        return link(
            prompt: prompt(items: items, generatedAt: generatedAt, now: now),
            folder: home + "/.agents"
        )
    }

    public static func link(
        section: SetupSectionResult,
        problem: SetupResult,
        generatedAt: Date?,
        now: Date = Date(),
        home: String = NSHomeDirectory()
    ) -> URL? {
        link(items: [Item(section: section, problem: problem)],
             generatedAt: generatedAt, now: now, home: home)
    }

    /// The app reads the query with URLSearchParams, which turns a bare "+"
    /// into a space. Only the unreserved characters go through unescaped.
    static func encode(_ text: String) -> String {
        let unreserved = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}
