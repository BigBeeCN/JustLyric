import XCTest
@testable import LyricsCore

/// 脏话掩码测试（S7 D22；双方向勿混——Fix 还原 / Clean 掩码）。
final class ExplicitCleanTests: XCTestCase {
    /// Fix：还原误写掩码（方向一）。
    func testFixRestoresMaskedForms() {
        XCTAssertEqual(ExplicitClean.fix("What the f**k"), "What the fuck")
        XCTAssertEqual(ExplicitClean.fix("f*ck fu*k"), "fuck fuck")
        XCTAssertEqual(ExplicitClean.fix("mother****"), "motherfuck")
        XCTAssertEqual(ExplicitClean.fix("p***y p**sy"), "pussy pussy")
        XCTAssertEqual(ExplicitClean.fix("d**g"), "drug", "d**g 还原为 drug（非 dog）")
        XCTAssertEqual(ExplicitClean.fix("b***h b**ch"), "bitch bitch")
        XCTAssertEqual(ExplicitClean.fix("d**n d**mit"), "damn dammit")
    }

    /// Clean strong：先还原再整词全星号（方向二）。
    func testCleanStrongMasksFully() {
        XCTAssertEqual(ExplicitClean.clean("you bitch", strong: true), "you *****")
        XCTAssertEqual(ExplicitClean.clean("damn it", strong: true), "**** it")
        XCTAssertEqual(ExplicitClean.clean("what the f**k", strong: true), "what the ****")
        XCTAssertEqual(ExplicitClean.clean("Bitch", strong: true), "*****")
        XCTAssertEqual(ExplicitClean.clean("bitches", strong: true), "*****")
    }

    /// Clean 弱档：保留首尾字母。
    func testCleanWeakPartialMasks() {
        XCTAssertEqual(ExplicitClean.clean("you bitch"), "you b***h")
        XCTAssertEqual(ExplicitClean.clean("damn"), "d**n")
        XCTAssertEqual(ExplicitClean.clean("fuck"), "f**k")
        XCTAssertEqual(ExplicitClean.clean("Bitch"), "B***h")
        XCTAssertEqual(ExplicitClean.clean("sex"), "s*x")
    }

    /// 独立词上下文：ass/Ass/hoe 仅独立时掩码（classic/pass 不误伤）。
    func testStandaloneContextMasking() {
        XCTAssertEqual(ExplicitClean.clean("you ass"), "you a*s")
        XCTAssertEqual(ExplicitClean.clean("Ass up"), "A*s up")
        XCTAssertEqual(ExplicitClean.clean("classic pass", strong: true), "classic pass", "词内不误伤")
        XCTAssertEqual(ExplicitClean.clean("ass-hole"), "a*s-hole", "连字符边界算独立")
    }

    /// 双方向独立（提示 #1：别混）——fix 与 clean 输出不交叉。
    func testDirectionsAreDistinct() {
        let masked = "f**k"
        XCTAssertEqual(ExplicitClean.fix(masked), "fuck")
        XCTAssertEqual(ExplicitClean.clean(masked), "f**k", "clean 不做还原（弱档无该词映射，保持原样）")
    }
}
