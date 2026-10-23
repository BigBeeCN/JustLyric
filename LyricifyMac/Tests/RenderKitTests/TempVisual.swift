import AppKit
import LyricsCore
import XCTest
@testable import RenderKit

final class TempVisual: XCTestCase {
    final class StubClock: TimelineProviding {
        let ms: Int
        init(ms: Int) {
            self.ms = ms
        }

        func elapsed(now: TimeInterval) -> Int {
            ms
        }
    }

    func testVisualDump() throws {
        let line = LyricsLine(
            startMs: 0,
            endMs: 3000,
            text: "你就是我的风景云高风清不走下去停在这里视线里都是风景",
            syllables: (0 ..< 10).map {
                Syllable(text: "你就是我的风景云高风清不走下去停在这里视线里都是风景", startMs: $0 * 300, durationMs: 300)
            }
        )
        for (name, elapsed) in [("start", 0), ("mid", 1500), ("end", 3000)] {
            let view = KaraokeTextView(line: line, clock: StubClock(ms: elapsed))
            view.wrapsText = true
            view.frame = CGRect(x: 0, y: 0, width: 800, height: 160)
            view.tick(now: 0)
            let png = SnapshotRenderer.png(of: view, size: CGSize(width: 800, height: 160), dark: false)
            try png.write(to: URL(fileURLWithPath: "/tmp/long-\(name).png"))
            print("VISUAL done \(name) mask=\(view.lastMaskWidth)")
        }
    }
}
