import SwiftUI

// The Static panel: how many findings the Pitch workspace's Static engine lists
// (dead references, for the most part), and one control that sends all of them
// to Raya in a new Claude Code session in ~/pitch. The count turns red at
// `StaticBlock.sendThreshold`, which is the cue to send them.
//
// The engine builds the prompt and the link, so this panel and the Pitch
// dashboard ask for the same fix. The link only fills the composer.

public struct StaticSection: View {
    public let block: StaticBlock?
    /// Called with the fix-session link. Nil in previews and tests, which is
    /// why it is a seam rather than a direct open.
    public var onSend: ((URL) -> Void)?

    public init(block: StaticBlock?, onSend: ((URL) -> Void)? = nil) {
        self.block = block
        self.onSend = onSend
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionRule(title: "STATIC") { headerStatus }
            if let block {
                if !block.isClear { findingsRow(block) }
            } else {
                unknownRow
            }
        }
    }

    private var headerStatus: some View {
        Text(Self.headerText(block))
            .font(Theme.label(11))
            .tracking(0.4)
            .foregroundStyle(Self.headerColor(block))
            .fixedSize()
    }

    static func headerText(_ block: StaticBlock?) -> String {
        guard let block else { return "unknown" }
        if block.isClear { return "clear" }
        return block.count == 1 ? "1 finding" : "\(block.count) findings"
    }

    static func headerColor(_ block: StaticBlock?) -> Color {
        guard let block else { return Theme.muted }
        if block.isClear { return Theme.green }
        return block.isDue ? Theme.red : Theme.forest
    }

    static func sendTitle(_ count: Int) -> String {
        count == 1 ? "send it to Raya" : "send all \(count) to Raya"
    }

    private func findingsRow(_ block: StaticBlock) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.isDue ? "Time to send these to Raya." : "Dead references and other findings in ~/pitch.")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.text)
                Text("score \(block.score) · \(block.band.lowercased())")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            if let onSend {
                FixSessionButton(
                    title: Self.sendTitle(block.count),
                    link: block.fixLink,
                    help: block.fixLink == nil
                        ? "The Static engine gave no session link."
                        : "Ask Raya to fix every Static finding in one new Claude Code session in ~/pitch",
                    onFix: onSend
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var unknownRow: some View {
        HStack(spacing: 10) {
            Circle().fill(Theme.faint).frame(width: 6, height: 6)
            Text("could not run ~/pitch/bin/static.mjs --json")
                .font(Theme.label(12))
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
    }
}
