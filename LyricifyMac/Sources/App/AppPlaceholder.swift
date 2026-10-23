// App 占位编译单元（M4/M5 组装落位后删除）。

/// App 模块占位类型。
///
/// > Warning: 仅用于脚手架期保证 target 可编译；M5 组装为 executable 时删除。
/// > Note: 假设 A7 —— App target 脚手架期为 library，M5 组装时改 executable。
enum AppPlaceholder {
    /// 占位标识。
    static let moduleName = "App"
}
