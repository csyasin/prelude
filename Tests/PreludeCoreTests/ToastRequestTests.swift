import XCTest
@testable import PreludeCore

final class ToastRequestTests: XCTestCase {
    func testEncodedUnicodeAndReservedCharacters() throws {
        var parts = URLComponents(string: "prelude://toast")!
        parts.queryItems = [URLQueryItem(name: "message", value: "完成 & 100% + # ? $(echo hello)")]
        let request = try ToastRequest(url: parts.url!)
        XCTAssertEqual(request.message, "完成 & 100% + # ? $(echo hello)")
        XCTAssertEqual(request.duration, 1)
    }

    func testDurationAndWhitespace() throws {
        let request = try ToastRequest(url: XCTUnwrap(URL(string: "prelude://toast/?message=%20hello%0Aworld%20&duration=2.5")))
        XCTAssertEqual(request.message, "hello world")
        XCTAssertEqual(request.duration, 2.5)
    }

    func testRejectsInvalidDuration() {
        for value in ["0", "-1", "0.49", "11", "nan", "inf", "text", ""] {
            XCTAssertThrowsError(try ToastRequest(url: URL(string: "prelude://toast?message=hello&duration=\(value)")!))
        }
    }

    func testRejectsAmbiguousOrUnsupportedRequests() {
        for address in ["https://toast?message=hello", "prelude://run?message=hello",
                        "prelude://toast/extra?message=hello", "prelude://toast?message=hello#fragment",
                        "prelude://toast", "prelude://toast?message=%20%0A", "prelude://toast?message",
                        "prelude://toast?message=a&message=b", "prelude://toast?message=a&command=anything",
                        "prelude://user@toast?message=a", "prelude://toast:80?message=a"] {
            XCTAssertThrowsError(try ToastRequest(url: URL(string: address)!), address)
        }
    }

    func testTypesAndOptionalIcon() throws {
        for type in ToastKind.allCases {
            let parsed = try ToastRequest(url: URL(string: "prelude://toast?message=hello&type=\(type.rawValue)")!)
            XCTAssertEqual(parsed.type, type)
        }
        XCTAssertNil(try ToastRequest(url: URL(string: "prelude://toast?message=hello")!).type)
        XCTAssertNil(try ToastRequest(url: URL(string: "prelude://toast?message=hello&type=")!).type)
        XCTAssertThrowsError(try ToastRequest(url: URL(string: "prelude://toast?message=hello&type=unknown")!))
        XCTAssertThrowsError(try ToastRequest(url: URL(string: "prelude://toast?message=hello&type=success&type=error")!))
        let internalFeedback = ToastRequest(message: "Capture Area", type: .success)
        XCTAssertEqual(internalFeedback.duration, 1)
        XCTAssertEqual(internalFeedback.type, .success)
    }

    func testMessageLengthBoundary() throws {
        XCTAssertEqual(try ToastRequest(url: URL(string: "prelude://toast?message=" + String(repeating: "a", count: 200))!).message.count, 200)
        XCTAssertThrowsError(try ToastRequest(url: URL(string: "prelude://toast?message=" + String(repeating: "a", count: 201))!))
    }
}
