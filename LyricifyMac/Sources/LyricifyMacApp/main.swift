import App
import AppKit
import MediaSession

/// LyricifyMac 入口（S7 A7：App target 保持 library，入口为独立 executable 壳）。
@main
enum LyricifyMacMain {
    static func main() {
        let app = NSApplication.shared
        let coordinator = AppCoordinator()

        // 单实例（S5 §2）。
        let bundleID = Bundle.main.bundleIdentifier ?? "com.bigbeecn.justlyric"
        let running = SingleInstance.existingInstances(bundleIdentifier: bundleID).count
        if AppLifecycle.shouldYieldToExisting(bundleID: bundleID, running: running) {
            for existingInstance in SingleInstance.existingInstances(bundleIdentifier: bundleID) {
                SingleInstance.activate(existingInstance)
            }
            return
        }

        let mode = PermissionGuide.mode(mediaRemoteAvailable: true)
        let log = coordinator.start(mode: mode, automationDenied: false)
        NSLog("%@", log) // os.Logger 本地（S5 §4 零遥测）
        app.run()
    }
}
