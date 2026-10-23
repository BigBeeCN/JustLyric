import AppKit

/// 快照基准（S7 D30 #4：dark/light × 系统字体 17pt 固定，消除字体抖动）。
public enum SnapshotBaseline {
    /// 基准字体（17pt 系统字体，D30 #4）。
    public static let font = KaraokeTextView.snapshotFont
    /// 渲染倍率（固定 1.0——同机重跑零抖动判据的一部分）。
    public static let scale: CGFloat = 1.0
}

/// 快照渲染/比对（自研 CG 位图，D32 选型备案：判据 = 同机重跑零抖动）。
public enum SnapshotRenderer {
    /// 渲染视图为 PNG。
    /// - Parameters:
    ///   - view: 视图（会被铺设到给定尺寸）。
    ///   - size: 画布尺寸（pt）。
    ///   - dark: 深色外观。
    /// - Returns: PNG 数据。
    public static func png(of view: NSView, size: CGSize, dark: Bool) -> Data {
        let frame = CGRect(origin: .zero, size: size)
        view.frame = frame
        view.layoutSubtreeIfNeeded()
        view.layer?.displayIfNeeded() // CATextLayer 等内容先完成 display 栅格化

        let pixelsWide = Int(size.width * SnapshotBaseline.scale)
        let pixelsHigh = Int(size.height * SnapshotBaseline.scale)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = size

        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            appearance.performAsCurrentDrawingAppearance {
                forceDisplay(view.layer)
                renderViewTree(view, in: context.cgContext, origin: .zero)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }

    /// 递归视图树渲染（AppKit 视图挂载子层惰性——目检教训：
    /// 仅 `layer.render` 会漏绘未挂载的子视图，逐视图递归并跳过已挂载子层防双绘）。
    private static func renderViewTree(_ view: NSView, in context: CGContext, origin: CGPoint) {
        context.saveGState()
        context.translateBy(x: origin.x, y: origin.y)
        if let layer = view.layer {
            forceDisplay(layer)
            layer.render(in: context)
        }
        let attached = Set((view.layer?.sublayers ?? []).map { ObjectIdentifier($0) })
        for subview in view.subviews {
            guard let sublayer = subview.layer,
                  !attached.contains(ObjectIdentifier(sublayer)) else { continue }
            renderViewTree(
                subview,
                in: context,
                origin: CGPoint(x: subview.frame.origin.x, y: subview.frame.origin.y)
            )
        }
        context.restoreGState()
    }

    /// 递归强制 display（CATextLayer 等离屏内容栅格化）。
    private static func forceDisplay(_ layer: CALayer?) {
        guard let layer else { return }
        layer.setNeedsDisplay()
        layer.displayIfNeeded()
        for sublayer in layer.sublayers ?? [] {
            forceDisplay(sublayer)
        }
    }

    /// 字节级比对（同机重跑零抖动判据）。
    /// - Parameters:
    ///   - a: 图像数据。
    ///   - b: 图像数据。
    /// - Returns: 完全一致。
    public static func matches(_ a: Data, _ b: Data) -> Bool {
        a == b
    }
}
