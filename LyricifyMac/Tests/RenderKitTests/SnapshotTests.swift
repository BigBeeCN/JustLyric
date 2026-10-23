import AppKit
import LyricsCore
import XCTest
@testable import RenderKit

/// 快照矩阵测试（S6 §4；S7 D30 #4 基准 + D33 #4 样式面接线 + D33 #5 重录规则）。
///
/// 生成基线：`REGEN_SNAPSHOT=1 swift test --filter SnapshotTests`
/// （同机基线——判据 = 同机重跑零抖动，D32 选型备案）。
final class SnapshotTests: XCTestCase {
    /// 固定时钟（D30 #5）。
    private final class StubClock: TimelineProviding {
        let ms: Int
        init(ms: Int) {
            self.ms = ms
        }

        func elapsed(now: TimeInterval) -> Int {
            ms
        }
    }

    private static let canvas = CGSize(width: 320, height: 80)

    /// 按样式预设取字体（D33 #4：字号/字重固定——确定性）。
    private func presetFont(_ preset: DesktopLyricsStyle.Preset) -> NSFont {
        let style = DesktopLyricsStyle.preset(preset)
        return NSFont.systemFont(
            ofSize: CGFloat(style.fontSize),
            weight: style.bold ? .bold : .regular
        )
    }

    private func karaokeView(
        elapsedMs: Int,
        preset: DesktopLyricsStyle.Preset,
        wraps: Bool = false
    ) -> KaraokeTextView {
        let line = LyricsLine(
            startMs: 0,
            endMs: 2000,
            text: "词一词二词三",
            syllables: [
                Syllable(text: "词一", startMs: 0, durationMs: 700),
                Syllable(text: "词二", startMs: 700, durationMs: 600),
                Syllable(text: "词三", startMs: 1300, durationMs: 700),
            ]
        )
        let view = KaraokeTextView(line: line, clock: StubClock(ms: elapsedMs), font: presetFont(preset))
        view.wrapsText = wraps
        view.frame = CGRect(origin: .zero, size: Self.canvas)
        view.tick(now: 0)
        return view
    }

    /// 快照矩阵（D33 #4 三套样式接线）：状态 × dark/light。
    func testSnapshotMatrix() throws {
        let duo = DuetLayoutView(
            firstLine: karaokeView(elapsedMs: 600, preset: .duoLine),
            secondLine: karaokeView(elapsedMs: 0, preset: .duoLine)
        )
        duo.frame = CGRect(origin: .zero, size: Self.canvas)
        duo.layoutSubtreeIfNeeded()

        let states: [(String, NSView)] = [
            // singleLine（24pt Bold）：未唱/唱一半/唱完/长句换行。
            ("single-untouched", karaokeView(elapsedMs: 0, preset: .singleLine)),
            ("single-halfway", karaokeView(elapsedMs: 1000, preset: .singleLine)),
            ("single-finished", karaokeView(elapsedMs: 2000, preset: .singleLine)),
            ("single-wrapped", karaokeView(elapsedMs: 500, preset: .singleLine, wraps: true)),
            // duoLine（22+16pt 副行 70%）：副行/对唱。
            ("duoline-subline", karaokeView(elapsedMs: 600, preset: .duoLine)),
            ("duoline-duet", duo),
            // karaoke（24pt Bold + D30#3）：唱一半。
            ("karaoke-halfway", karaokeView(elapsedMs: 1000, preset: .karaoke)),
        ]

        let regen = ProcessInfo.processInfo.environment["REGEN_SNAPSHOT"] == "1"
        let directory = FixtureLoader.directoryURL().appendingPathComponent("Snapshots")
        if regen {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        for (name, view) in states {
            for dark in [false, true] {
                let png = SnapshotRenderer.png(of: view, size: Self.canvas, dark: dark)
                XCTAssertFalse(png.isEmpty, name)
                let file = "\(name)-\(dark ? "dark" : "light").png"
                let url = directory.appendingPathComponent(file)
                if regen {
                    try png.write(to: url)
                } else {
                    let expected = try Data(contentsOf: url)
                    XCTAssertTrue(
                        SnapshotRenderer.matches(expected, png),
                        "快照不一致：\(file)（合法变更请 REGEN_SNAPSHOT=1 重生成并人工目检，D33 #5）"
                    )
                }
            }
        }
    }

    /// 同机重跑零抖动（D32 选型判据）。
    func testSameMachineDeterminism() {
        let view = karaokeView(elapsedMs: 1000, preset: .karaoke)
        let first = SnapshotRenderer.png(of: view, size: Self.canvas, dark: true)
        let second = SnapshotRenderer.png(of: view, size: Self.canvas, dark: true)
        XCTAssertTrue(SnapshotRenderer.matches(first, second), "同机重跑必须字节一致")
    }

    /// 状态可区分（未唱/唱一半/唱完 互异）。
    func testStatesRenderDistinct() {
        let untouched = SnapshotRenderer.png(
            of: karaokeView(elapsedMs: 0, preset: .karaoke), size: Self.canvas, dark: true
        )
        let halfway = SnapshotRenderer.png(
            of: karaokeView(elapsedMs: 1000, preset: .karaoke), size: Self.canvas, dark: true
        )
        let finished = SnapshotRenderer.png(
            of: karaokeView(elapsedMs: 2000, preset: .karaoke), size: Self.canvas, dark: true
        )
        XCTAssertNotEqual(untouched, halfway)
        XCTAssertNotEqual(halfway, finished)
        XCTAssertNotEqual(untouched, finished)
    }
}
