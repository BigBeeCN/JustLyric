// swift-tools-version: 5.10
// LyricifyMac — macOS 原生逐字歌词应用。
// 依赖方向严格单向：App → RenderKit/MediaSession/Sources → LyricsCore（S0 §4）。
import PackageDescription

let package = Package(
    name: "LyricifyMac",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "LyricsCore", targets: ["LyricsCore"]),
        .library(name: "Sources", targets: ["Sources"]),
        .library(name: "MediaSession", targets: ["MediaSession"]),
        .library(name: "RenderKit", targets: ["RenderKit"]),
        // MediaRemoteAdapter 动态库（D37）：perl 宿主 dlopen 加载形态。
        .library(name: "MediaRemoteAdapterLib", type: .dynamic, targets: ["MediaRemoteAdapterCore"]),
    ],
    targets: [
        // 纯逻辑：模型/格式解析/生成/匹配/优化管线（无 UI、无网络副作用）。
        .target(
            name: "LyricsCore",
            // S7 D5/D15：OpenCC 官方词典（Apache-2.0）随包分发（About 页许可证义务记 M5 清单）。
            resources: [
                .copy("Resources/OpenCC"),
            ]
        ),
        // 数据源适配器：LRCLIB / AppleTTML / LocalFiles / 插件协议（M2）。
        .target(
            name: "Sources",
            dependencies: ["LyricsCore"],
            exclude: ["Plugins"], // 插件合规声明（非代码）
            linkerSettings: [
                .linkedLibrary("sqlite3"), // T2.06 缓存
            ]
        ),
        // 媒体会话：MediaRemote / 直连 / 时间轴平滑 / 延迟校准（M2）。
        // MediaRemoteAdapter 核心（S7 D37）：dlopen/dlsym 单点 dylib（符号唯一落点）。
        .target(
            name: "MediaRemoteAdapterCore",
            path: "Sources/MediaRemoteAdapterCore"
        ),
        .target(
            name: "MediaSession",
            dependencies: ["LyricsCore"],
            resources: [
                .copy("MediaRemoteAdapter/adapter-host.pl"), // perl 宿主脚本（D37）
            ]
        ),
        // 逐字渲染组件与动画参数系统（M3）。
        .target(
            name: "RenderKit",
            dependencies: ["LyricsCore"]
        ),
        // 组装：设置/窗口/菜单栏/系统集成/生命周期（M4/M5）。
        .target(
            name: "App",
            dependencies: ["LyricsCore", "Sources", "MediaSession", "RenderKit"]
        ),
        .testTarget(
            name: "LyricsCoreTests",
            dependencies: ["LyricsCore"]
        ),
        .testTarget(
            name: "SourcesTests",
            dependencies: ["Sources"]
        ),
        .testTarget(
            name: "MediaSessionTests",
            dependencies: ["MediaSession"]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["App"]
        ),
        .executableTarget(
            name: "M2Probe",
            dependencies: ["LyricsCore", "Sources", "MediaSession"]
        ),
        // 入口壳（S7 A7：App 保持 library；@main 在此）。
        .executableTarget(
            name: "LyricifyMacApp",
            dependencies: ["App", "LyricsCore", "Sources", "MediaSession", "RenderKit"]
        ),
        // M4 手测窗预览（显示侧补核工具）。
        .executableTarget(
            name: "LyricsPreview",
            dependencies: ["App", "LyricsCore", "Sources", "MediaSession", "RenderKit"]
        ),
        .testTarget(
            name: "RenderKitTests",
            dependencies: ["RenderKit"]
        ),
    ]
)
