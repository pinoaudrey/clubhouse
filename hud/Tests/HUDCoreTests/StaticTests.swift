import XCTest
@testable import HUDCore

final class StaticTests: XCTestCase {

    private func snapshot(staticJSON: String?) throws -> HUDSnapshot {
        let block = staticJSON.map { #", "static": \#($0)"# } ?? ""
        let json = #"{"version": 5, "generated_at": null, "subscriptions": [], "agents": []\#(block)}"#
        return try HUDSnapshot.decode(from: Data(json.utf8))
    }

    func testDecodesTheBlockAndItsLink() throws {
        let snap = try snapshot(staticJSON: """
            {"generated_at": "2026-10-29T19:34:00.000Z", "score": 102, "band": "CRITICAL",
             "count": 34, "fix_link": "claude://code/new?q=raya%20please%20fix&folder=%2Ftmp"}
            """)
        let block = try XCTUnwrap(snap.staticFindings)
        XCTAssertEqual(block.count, 34)
        XCTAssertEqual(block.score, 102)
        XCTAssertEqual(block.fixLink?.absoluteString, "claude://code/new?q=raya%20please%20fix&folder=%2Ftmp")
        XCTAssertTrue(block.isDue)
    }

    func testAPreV5SnapshotHasNoBlock() throws {
        XCTAssertNil(try snapshot(staticJSON: nil).staticFindings)
        XCTAssertNil(try snapshot(staticJSON: "null").staticFindings)
    }

    func testALinkWithAnotherSchemeIsDropped() throws {
        let snap = try snapshot(staticJSON: """
            {"generated_at": null, "score": 6, "band": "LOW", "count": 2,
             "fix_link": "https://example.com/?q=x"}
            """)
        let block = try XCTUnwrap(snap.staticFindings)
        XCTAssertEqual(block.count, 2)
        XCTAssertNil(block.fixLink)
    }

    func testABadTimestampCostsOnlyTheTimestamp() throws {
        let snap = try snapshot(staticJSON: """
            {"generated_at": "yesterday", "score": 0, "band": "CLEAR", "count": 0, "fix_link": null}
            """)
        let block = try XCTUnwrap(snap.staticFindings)
        XCTAssertNil(block.generatedAt)
        XCTAssertTrue(block.isClear)
    }

    func testTheCountTurnsRedAtTheSendThreshold() {
        func block(_ count: Int) -> StaticBlock {
            StaticBlock(generatedAt: nil, score: count * 3, band: "HIGH", count: count, fixLink: nil)
        }
        XCTAssertEqual(StaticSection.headerColor(block(StaticBlock.sendThreshold - 1)), Theme.forest)
        XCTAssertEqual(StaticSection.headerColor(block(StaticBlock.sendThreshold)), Theme.red)
        XCTAssertEqual(StaticSection.headerColor(block(0)), Theme.green)
        XCTAssertEqual(StaticSection.headerColor(nil), Theme.muted)
    }

    func testTheHeaderAndButtonNameTheCount() {
        XCTAssertEqual(StaticSection.headerText(nil), "unknown")
        XCTAssertEqual(StaticSection.headerText(.sampleClear), "clear")
        XCTAssertEqual(StaticSection.headerText(.sampleDue), "34 findings")
        XCTAssertEqual(StaticSection.sendTitle(1), "send it to Raya")
        XCTAssertEqual(StaticSection.sendTitle(34), "send all 34 to Raya")
    }
}
