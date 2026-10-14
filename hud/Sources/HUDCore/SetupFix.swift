import Foundation

/// Clicking a setup problem opens a new Claude Code session in `~/.agents`
/// with a prompt for that one problem in the composer.
///
/// The link only fills the composer: the session starts when you press
/// Enter, so a stray click costs nothing. One problem per session keeps each
/// fix to one branch and one PR.
///
/// Pure text and URL assembly, so tests check the link without opening it.
public enum SetupFix {

    /// The Claude app cuts `q` at this many characters.
    static let promptLimit = 14_336

    /// The rules a single-problem session needs on top of the clipboard's.
    /// The app starts a session in a worktree of `~/.agents`, and the scripts
    /// in `bin/` default to the shared checkout.
    static let sessionRules = [
        "This session can run in a git worktree of ~/.agents. Set AGENTS_DIR to the worktree when you run bin/capture.sh, so the capture lands on your branch.",
    ]

    public static func prompt(
        section: SetupSectionResult,
        problem: SetupResult,
        generatedAt: Date?,
        now: Date = Date()
    ) -> String {
        var lines = ["My ~/.agents setup has 1 problem. Please fix it."]
        lines.append("")
        lines.append("Reported by bin/check-setup.sh, \(SetupClipboard.stamp(generatedAt ?? now)).")
        lines.append("")
        lines.append(contentsOf: SetupClipboard.problemLines(number: 1, section: section, problem: problem))
        lines.append("")
        lines.append("Rules from ~/.agents/AGENTS.md that apply here:")
        lines.append(contentsOf: (SetupClipboard.rules + sessionRules).map { "- \($0)" })
        return lines.joined(separator: "\n") + "\n"
    }

    /// `claude://code/new?q=…&folder=…`, the link the Claude app's own dock
    /// menu uses for a new Code session in a folder. Nil when the prompt is
    /// too long for the app to take whole.
    public static func link(prompt: String, folder: String) -> URL? {
        guard prompt.count <= promptLimit else { return nil }
        return URL(string: "claude://code/new?q=\(encode(prompt))&folder=\(encode(folder))")
    }

    public static func link(
        section: SetupSectionResult,
        problem: SetupResult,
        generatedAt: Date?,
        now: Date = Date(),
        home: String = NSHomeDirectory()
    ) -> URL? {
        link(
            prompt: prompt(section: section, problem: problem, generatedAt: generatedAt, now: now),
            folder: home + "/.agents"
        )
    }

    /// The app reads the query with URLSearchParams, which turns a bare "+"
    /// into a space. Only the unreserved characters go through unescaped.
    static func encode(_ text: String) -> String {
        let unreserved = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}
