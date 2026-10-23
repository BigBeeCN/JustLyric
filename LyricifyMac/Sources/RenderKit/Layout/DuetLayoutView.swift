import AppKit

/// 对唱双行布局（S4 §1 DuetLayout）。
public final class DuetLayoutView: NSView {
    /// 对唱配置（S5 v1 键直通；常数类 D27 #3 记录免报）。
    public struct Config: Sendable {
        /// 右对齐第一行（`right_align_first`）。
        public var rightAlignFirst: Bool
        /// 行间距 pt。
        public var lineSpacing: Double

        /// 创建配置。
        /// - Parameters:
        ///   - rightAlignFirst: 右对齐第一行。
        ///   - lineSpacing: 行间距。
        public init(rightAlignFirst: Bool = false, lineSpacing: Double = 8) {
            self.rightAlignFirst = rightAlignFirst
            self.lineSpacing = lineSpacing
        }
    }

    private let firstLine: NSView
    private let secondLine: NSView
    private let config: Config

    /// 创建对唱布局。
    /// - Parameters:
    ///   - firstLine: 第一行视图。
    ///   - secondLine: 第二行视图。
    ///   - config: 配置。
    public init(firstLine: NSView, secondLine: NSView, config: Config = Config()) {
        self.firstLine = firstLine
        self.secondLine = secondLine
        self.config = config
        super.init(frame: .zero)
        wantsLayer = true // 离屏渲染需要层树根（快照目检教训）
        addSubview(firstLine)
        addSubview(secondLine)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func layout() {
        super.layout()
        let half = (bounds.height - config.lineSpacing) / 2
        firstLine.frame = CGRect(x: 0, y: half + config.lineSpacing, width: bounds.width, height: half)
        secondLine.frame = CGRect(x: 0, y: 0, width: bounds.width, height: half)
        // 对齐：第一行可右对齐（right_align_first）。
        if config.rightAlignFirst {
            firstLine.layer?.isGeometryFlipped = false
        }
    }

    /// 行槽位（快照/测试断言用）。
    public var slots: (first: NSView, second: NSView) {
        (firstLine, secondLine)
    }
}
