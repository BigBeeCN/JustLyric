# 安装与自签（ad-hoc 版本）

因未使用 Apple Developer ID 签名，首次打开需放行：

## 方式一：右键打开（推荐）
1. 解压 zip → 将 JustLyric.app 拖入「应用程序」；
2. **右键点击 App → 选「打开」→ 弹窗选「打开」**（仅首次需要）。

## 方式二：命令行放行
```bash
xattr -dr com.apple.quarantine /Applications/JustLyric.app
```

## 方式三：自行重签
```bash
codesign --force --deep -s - /Applications/JustLyric.app
```

> 自动更新（Sparkle）在 ad-hoc 分发下未启用，请关注 Release 页获取新版。
