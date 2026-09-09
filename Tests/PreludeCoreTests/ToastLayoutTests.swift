import XCTest
@testable import PreludeCore

final class ToastLayoutTests: XCTestCase {
    func testShortMessageKeepsMinimumWidthWithoutStretchingText() {
        for hasIcon in [true, false] {
            let layout = ToastLayout.measure(message: "已保存", hasIcon: hasIcon,
                minimumWidth: 270, maximumWidth: 756, horizontalPadding: 26)
            XCTAssertEqual(layout.width, 270)
            XCTAssertLessThan(layout.textWidth, 100)
            XCTAssertEqual(layout.contentHeight, 32)
        }
    }

    func testLongMessageGrowsThenWrapsAtHalfDisplayWidth() {
        let message = String(repeating: "通知内容需要完整显示", count: 20)
        for displayWidth: CGFloat in [1024, 1512, 2560] {
            let cap = displayWidth / 2
            let layout = ToastLayout.measure(message: message, hasIcon: true,
                minimumWidth: 270, maximumWidth: cap, horizontalPadding: 26)
            XCTAssertEqual(layout.width, cap)
            XCTAssertLessThanOrEqual(layout.textWidth + 43 + 52, cap)
            XCTAssertGreaterThan(layout.contentHeight, 32)
        }
    }

    func testUnbrokenTextAndEmojiHaveRoomToWrap() {
        for message in [String(repeating: "W", count: 200), String(repeating: "👩🏽‍💻", count: 100)] {
            let layout = ToastLayout.measure(message: message, hasIcon: false,
                minimumWidth: 270, maximumWidth: 512, horizontalPadding: 26)
            XCTAssertEqual(layout.width, 512)
            XCTAssertGreaterThan(layout.contentHeight, 32)
        }
    }
}
