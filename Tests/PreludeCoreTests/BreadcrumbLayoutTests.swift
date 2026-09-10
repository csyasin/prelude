import XCTest
@testable import PreludeCore

final class BreadcrumbLayoutTests: XCTestCase {
    func testKeepsMoreThanTwoLevelsWhenTheyFit() {
        let labels = ["System", "Audio", "Output", "Volume"]
        let result = BreadcrumbLayout.fit(labels: labels, availableWidth: 400)
        XCTAssertEqual(result.labels, labels)
        XCTAssertEqual(result.omittedCount, 0)
    }

    func testDropsOnlyLeadingAncestors() {
        let labels = [String(repeating: "Very long ancestor ", count: 8), "Audio", "Output", "Volume"]
        let result = BreadcrumbLayout.fit(labels: labels, availableWidth: 240)
        XCTAssertEqual(result.labels, ["Audio", "Output", "Volume"])
        XCTAssertEqual(result.omittedCount, 1)
    }

    func testWiderPanelRestoresMoreOfPath() {
        let labels = ["Application", "Workspace", "Project", "Source", "Editor"]
        let narrow = BreadcrumbLayout.fit(labels: labels, availableWidth: 130)
        let wide = BreadcrumbLayout.fit(labels: labels, availableWidth: 400)
        XCTAssertGreaterThan(narrow.omittedCount, wide.omittedCount)
        XCTAssertEqual(narrow.labels.last, "Editor")
        XCTAssertEqual(wide.labels, labels)
    }

    func testAlwaysKeepsCurrentGroupAndHandlesRoot() {
        XCTAssertTrue(BreadcrumbLayout.fit(labels: [], availableWidth: 200).labels.isEmpty)
        let current = String(repeating: "当前分组", count: 20)
        let result = BreadcrumbLayout.fit(labels: ["System", current], availableWidth: 30)
        XCTAssertEqual(result.labels, [current])
        XCTAssertEqual(result.omittedCount, 1)
    }
}
