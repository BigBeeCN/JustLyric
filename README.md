# JustLyric

macOS 原生歌词显示工具——支持**所有向系统媒体控制上报的播放器**（经系统媒体接口适配），
覆盖 Spotify、Apple Music、网易云、浏览器媒体页等（实测清单见 Release Notes）。

## 安装（ad-hoc 签名版）

1. 下载 `JustLyric.app.zip`，校验 SHA-256（见 `SHA256SUMS.txt`）；
2. 解压得到 `JustLyric.app`，**移入「应用程序」文件夹**；
3. **自签/放行**（ad-hoc 分发必做，二选一）：
   - 图形方式：**右键点击 JustLyric.app → 打开 → 确认**（仅首次）；
   - 命令方式：`xattr -dr com.apple.quarantine /Applications/JustLyric.app`
     （或自行重签：`codesign --force -s - /Applications/JustLyric.app`）；
4. 启动后授权「媒体资料库/自动化」提示（用于读取播放状态），开始播放任意歌曲即显示歌词。

> macOS 14+（Sonoma）。

## 功能

- 逐字/逐行歌词实时显示（行扫掠推进、时间轴校准）
- 支持所有向系统媒体控制上报的播放器（经系统媒体接口适配）：系统媒体会话通道 + 直连 + 窗口标题三级降级
- 实测清单：Spotify、Apple Music、网易云音乐、浏览器媒体页（YouTube 等）——更多 app 持续适配
- 本地歌词文件 / LRCLIB 开放数据源；本地优先、**零遥测、零上传**

## 隐私

- 全部数据本地存储；网络仅用于检索歌词（LRCLIB 开放 API）；
- 播放状态经系统媒体接口读取，不收集、不上传任何信息。

## 说明

- 歌词数据来源：LRCLIB（开放 API）与用户本地文件；
- 本项目不含任何歌词文本、专有字体或第三方美术资产；
- 播放器商标归各自权利人；本工具仅读取系统公开的媒体会话信息。
