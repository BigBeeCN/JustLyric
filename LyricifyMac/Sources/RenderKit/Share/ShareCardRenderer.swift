import AppKit
import CoreImage

/// 分享卡片素材（S5 §2 v2；S0 §3 [红线-P1]：仅系统字体/OFL，导出含来源署名行）。
public struct ShareCard: Equatable, Sendable {
    /// 曲名。
    public var title: String
    /// 歌手。
    public var artist: String
    /// 歌词行。
    public var lyricLine: String
    /// 来源署名（如 `LRCLIB`）。
    public var source: String

    /// 创建卡片素材。
    public init(title: String, artist: String, lyricLine: String, source: String) {
        self.title = title
        self.artist = artist
        self.lyricLine = lyricLine
        self.source = source
    }
}

/// 分享卡片渲染（CoreGraphics；系统字体——合规红线）。
public enum ShareCardRenderer {
    /// 署名行格式（[红线-P1]：导出图片必含）。
    public static func attributionLine(_ card: ShareCard) -> String {
        "来自 JustLyric · 歌词来源：\(card.source) · \(card.title) - \(card.artist)"
    }

    /// 渲染卡片 PNG（系统字体 17pt 基准，D30 #4）。
    /// - Parameters:
    ///   - card: 素材。
    ///   - size: 画布。
    /// - Returns: PNG 数据。
    public static func render(_ card: ShareCard, size: CGSize = CGSize(width: 600, height: 800)) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            let cg = context.cgContext
            cg.setFillColor(NSColor.black.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            // 歌词行（系统字体——S0 §3 合规）。
            let font = SnapshotBaseline.font
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white,
            ]
            (card.lyricLine as NSString).draw(
                at: CGPoint(x: 40, y: 300),
                withAttributes: attrs
            )
            (card.title as NSString).draw(
                at: CGPoint(x: 40, y: 380),
                withAttributes: [.font: NSFont.systemFont(ofSize: 24, weight: .bold), .foregroundColor: NSColor.white]
            )
            // 署名行（必含，[红线-P1]）。
            (attributionLine(card) as NSString).draw(
                at: CGPoint(x: 40, y: size.height - 60),
                withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.gray]
            )
            NSGraphicsContext.restoreGraphicsState()
            return rep.representation(using: .png, properties: [:]) ?? Data()
        }
        NSGraphicsContext.restoreGraphicsState()
        return Data()
    }

    /// 二维码（分享链接/署名）。
    /// - Parameter content: 内容。
    /// - Returns: PNG 数据。
    public static func qrCode(from content: String) -> Data? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(content.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else {
            return nil
        }
        let rep = NSCIImageRep(ciImage: output)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image.tiffRepresentation
    }
}
