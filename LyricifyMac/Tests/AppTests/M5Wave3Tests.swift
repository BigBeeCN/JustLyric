import XCTest
@testable import App
@testable import RenderKit

/// M5 波次 3 测试（D46 #3 校准生产化硬项；S0 §3 素材合规；S5 §2 备份）。
final class M5Wave3Tests: XCTestCase {
    private func tempStore() -> SettingsStore {
        SettingsStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("cal-\(UUID().uuidString).json")
        )
    }

    /// 校准生产化：tap → 均值 → 写入设置 → 四层求和生效偏移（A5 正=延后）。
    func testCalibrationProduction() throws {
        let service = CalibrationService(settingsStore: tempStore())
        XCTAssertEqual(service.effectiveOffsetMs(sourceID: "lrclib", bundleID: nil), 0)

        service.recordTap(offsetMs: 100)
        service.recordTap(offsetMs: 200)
        XCTAssertEqual(service.sampledOffsetMs, 150)
        XCTAssertEqual(try service.commitToGlobal(), 150)

        // 四层求和生效（global 150 + 源延迟 30）。
        var settings = service.settingsStore.load()
        settings.sources.lyricsLatency = ["lrclib": 30]
        try service.settingsStore.save(settings)
        XCTAssertEqual(service.effectiveOffsetMs(sourceID: "lrclib", bundleID: nil), 180)
        XCTAssertEqual(service.effectiveOffsetMs(sourceID: nil, bundleID: nil), 150)
    }

    /// 每设备提交（D29 #1 语义沿用）。
    func testCommitPerDevice() throws {
        let service = CalibrationService(settingsStore: tempStore())
        service.recordTap(offsetMs: 150)
        XCTAssertEqual(try service.commitToDevice(deviceUID: "bt-1", deviceType: "bluetooth"), 150)
        let settings = service.settingsStore.load()
        XCTAssertEqual(settings.latency.deviceLatencyPerDevice.first?.id, "bt-1")
    }

    /// 备份/恢复：round-trip + 迁移器复用 + 坏 JSON 抛错（提示 #3）。
    func testBackupRoundTrip() throws {
        var settings = SettingsFile()
        settings.karaoke.karaokeStyleFloat = true
        settings.latency.deviceLatency = 280
        let data = try SettingsBackup.export(settings)
        let restored = try SettingsBackup.importSettings(data)
        XCTAssertTrue(restored.karaoke.karaokeStyleFloat)
        XCTAssertEqual(restored.latency.deviceLatency, 280)
        XCTAssertEqual(restored.version, SettingsMigrator.currentVersion)

        // 旧版本迁移（v0 → v1）。
        let legacy = Data("{\"general\":{\"language\":\"zh-Hans\"}}".utf8)
        let migrated = try SettingsBackup.importSettings(legacy)
        XCTAssertEqual(migrated.general.language, "zh-Hans")

        XCTAssertThrowsError(try SettingsBackup.importSettings(Data("not json".utf8)))
    }

    /// 分享卡片素材合规（S0 §3 [红线-P1]）：署名行必含、系统字体。
    func testShareCardCompliance() {
        let card = ShareCard(
            title: "测试曲", artist: "测试者", lyricLine: "测试歌词行", source: "LRCLIB"
        )
        XCTAssertTrue(ShareCardRenderer.attributionLine(card).contains("JustLyric"), "署名行必含")
        XCTAssertTrue(ShareCardRenderer.attributionLine(card).contains("LRCLIB"), "来源署名")
        let png = ShareCardRenderer.render(card, size: CGSize(width: 200, height: 200))
        XCTAssertFalse(png.isEmpty, "渲染产出")
        XCTAssertNotNil(ShareCardRenderer.qrCode(from: "https://example.com"))
    }
}
