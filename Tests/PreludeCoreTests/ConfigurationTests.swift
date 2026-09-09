import XCTest
@testable import PreludeCore

final class ConfigurationTests: XCTestCase {
    private let sample = """
    # Applications
    @ a - 应用
    s - Safari : open -b com.apple.Safari
    @@ t - 终端
    n - 脚本 : printf 'hello: #world'; echo "$HOME"
    @ a
    f - 访达 : open -b com.apple.finder
    """
    func testGroupsReferencesAndDeclarationOrder() throws {
        let c = try Configuration.parse(sample)
        XCTAssertEqual(c.tree[0].flattened.map(\.key), ["a","s","t","n","f"])
        XCTAssertEqual(c.bindings.map(\.sequence), [["a","s"],["a","t","n"],["a","f"]])
        XCTAssertEqual(c.bindings[1].action, "printf 'hello: #world'; echo \"$HOME\"")
    }
    func testCommentsAndShellAreNotInterpreted() throws {
        let c = try Configuration.parse("""
        # comment : @ ignored
          # indented comment
        @ g - 前往
        h - GitHub : open https://github.com/a#section
        p - 符号 : printf '# : @ -'; echo ${HOME:-/tmp} # shell comment
        """)
        XCTAssertEqual(c.bindings.count, 2)
        XCTAssertEqual(c.bindings[0].action, "open https://github.com/a#section")
        XCTAssertEqual(c.bindings[1].action, "printf '# : @ -'; echo ${HOME:-/tmp} # shell comment")
        XCTAssertEqual(try Configuration.parse("a - spaces : printf x  ").bindings[0].action, "printf x  ")
    }
    func testSwitchingContextClearsDeeperGroupsAndSupportsRoot() throws {
        let c = try Configuration.parse("""
        @ s - 系统
        @@ c - 截屏
        a - 截屏 : true
        @ g - 前往
        a - 地址 : true
        @ s
        p - 设置 : true
        @@ c
        b - 另一个 : true
        @
        x - 根动作 : true
        """)
        XCTAssertEqual(c.bindings.map(\.sequence), [["s","c","a"],["s","c","b"],["s","p"],["g","a"],["x"]])
    }
    func testLineNumbersAndInvalidStructures() {
        for input in [
            "# comment\n@@ c - skipped", "# comment\n@ missing", "# comment\n@ a - ",
            "# comment\na - empty : ", "# comment\na name true", "# comment\nA - upper : true"
        ] {
            XCTAssertThrowsError(try Configuration.parse(input)) { error in
                XCTAssertTrue(error.localizedDescription.contains("第 2 行"), error.localizedDescription)
            }
        }
        XCTAssertThrowsError(try Configuration.parse("@ a - empty"))
        XCTAssertThrowsError(try Configuration.parse("@ a - group\nx - leaf : true\n@ a - different"))
        XCTAssertThrowsError(try Configuration.parse("a - leaf : true\n@ a - group"))
        XCTAssertThrowsError(try Configuration.parse("a - leaf : true\na - duplicate : true"))
    }
    func testLeaderAndBOMWindowsLineEndings() throws {
        XCTAssertEqual(try Configuration.parse("\u{FEFF}# c\r\n!leader option+space\r\na - test : true\r\n").hotkey, Leader(key:"space",modifiers:["option"]))
        XCTAssertEqual(try Configuration.parse("!leader f12\na - test : true").hotkey.key,"f12")
        XCTAssertThrowsError(try Configuration.parse("!leader space\na - test : true"))
        XCTAssertThrowsError(try Configuration.parse("!leader ctrl+space\na - test : true"))
        XCTAssertThrowsError(try Configuration.parse("!leader f12\n!leader f11\na - test : true"))
    }
    func testRapidNavigationInvalidKeyAndBack() throws {
        let c = try Configuration.parse(sample)
        var nav = Navigator()
        for _ in 0..<10000 {
            XCTAssertEqual(nav.press("a", config:c), .branch)
            XCTAssertEqual(nav.press("t", config:c), .branch)
            XCTAssertEqual(nav.press("n", config:c), .action(c.bindings[1]))
            nav.reset()
        }
        _ = nav.press("a",config:c)
        XCTAssertEqual(nav.press("x",config:c),.invalid)
        XCTAssertEqual(nav.path,["a"])
        nav.back(); nav.back(); XCTAssertTrue(nav.path.isEmpty)
    }
    func testBundledRCAndMap() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let c = try Configuration.parse(String(contentsOf: root.appendingPathComponent("Sources/Prelude/Resources/preluderc"),encoding:.utf8))
        XCTAssertEqual(c.bindings.count,10)
        XCTAssertEqual(c.map.items.count,14)
        XCTAssertEqual(c.bindings.first { $0.sequence == ["g","c"] }?.action,"open -t \"$HOME/.config/prelude/preluderc\"")
        XCTAssertTrue(c.bindings.allSatisfy { !$0.action.contains("...") })
    }
}
