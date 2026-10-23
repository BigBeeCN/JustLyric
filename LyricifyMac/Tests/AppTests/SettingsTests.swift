import XCTest
@testable import App

/// 设置体系测试（S5 §1.1；S7 D35 ⭐：缺键回退组件默认禁崩、version+迁移器）。
final class SettingsTests: XCTestCase {
    private func tempStore() -> SettingsStore {
        SettingsStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("settings-\(UUID().uuidString).json")
        )
    }

    /// D35 ⭐：缺键回退组件默认（Karaoke=D30#3、阴影=D33#4）。
    func testMissingKeysFallBackToDefaults() throws {
        let json = "{\"version\":1}"
        let decoded = try JSONDecoder().decode(
            SettingsFile.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(decoded.karaoke.karaokeStyleFloatHeight, 2, accuracy: 0.001, "D30#3")
        XCTAssertEqual(decoded.karaoke.karaokeStyleProgressWidth, 8, accuracy: 0.001)
        XCTAssertEqual(decoded.karaoke.unplayingOpacityOverride, 0.55, accuracy: 0.001)
        XCTAssertEqual(decoded.desktopLyrics.shadowOpacity, 0.5, accuracy: 0.001, "D33#4")
        XCTAssertEqual(decoded.desktopLyrics.shadowRadius, 8, accuracy: 0.001)
        XCTAssertEqual(decoded.desktopLyrics.borderThickness, 0, "描边默认关")
    }

    /// 坏 JSON → 默认，禁崩。
    func testBadJSONFallsBack() {
        let store = tempStore()
        try? "{{ not json".write(to: store.fileURL, atomically: true, encoding: .utf8)
        let settings = store.load()
        XCTAssertEqual(settings.version, SettingsMigrator.currentVersion)
        XCTAssertTrue(settings.karaoke.isKaraoke)

        let missing = tempStore()
        XCTAssertEqual(missing.load().lyrics.romajiOption, .off)
    }

    /// round-trip + 原子写。
    func testSaveLoadRoundTrip() throws {
        let store = tempStore()
        var settings = SettingsFile()
        settings.karaoke.karaokeStyleFloat = true
        settings.desktopLyrics.duoLine = true
        settings.latency.deviceLatency = 150
        settings.sources.lyricsLatency = ["lrclib": 30]
        settings.sessions = [SessionEntry(id: "com.spotify.client")]
        try store.save(settings)

        let loaded = store.load()
        XCTAssertTrue(loaded.karaoke.karaokeStyleFloat)
        XCTAssertTrue(loaded.desktopLyrics.duoLine)
        XCTAssertEqual(loaded.latency.deviceLatency, 150)
        XCTAssertEqual(loaded.sources.lyricsLatency["lrclib"], 30)
        XCTAssertEqual(loaded.sessions.first?.id, "com.spotify.client")
    }

    /// 迁移器：v0 → v1（补 version 键）。
    func testMigration() {
        var json: [String: Any] = ["general": ["language": "zh-Hans"]]
        let migrated = SettingsMigrator.migrate(json: &json, fromVersion: 0)
        XCTAssertEqual(migrated, 1)
        XCTAssertEqual(json["version"] as? Int, 1)
    }

    /// S5 §1.1 关键映射抽验（MVP 键直通）。
    func testMVPKeyMapping() throws {
        let json = """
        {"version":1,
         "lyrics":{"translation":true,"romajiOption":"hiragana","titleLines":2},
         "desktopLyrics":{"lyricsAlign":"left","duoLine":true},
         "sources":{"localFilesPaths":["/tmp/lyrics"]}}
        """
        let decoded = try JSONDecoder().decode(SettingsFile.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.lyrics.translation)
        XCTAssertEqual(decoded.lyrics.romajiOption, .hiragana)
        XCTAssertEqual(decoded.lyrics.titleLines, 2)
        XCTAssertEqual(decoded.desktopLyrics.lyricsAlign, "left")
        XCTAssertEqual(decoded.sources.localFilesPaths, ["/tmp/lyrics"])
    }
}
