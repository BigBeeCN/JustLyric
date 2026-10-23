# Sources · 插件合规声明（S6 §6 交付物、S0 §3-2）

## 受限源红线

本仓库（LyricifyMac 核心）**不得包含**下列歌词源的接口调用实现：

- QQ 音乐
- 网易云音乐
- 酷狗音乐
- Musixmatch（其非公开 API；公开格式兼容输入除外）
- 汽水音乐

核心仓库仅内置三个数据源：**LRCLIB（开放 API）、Apple Music TTML（用户自持 MediaUserToken）、
本地歌词文件**。

## 插件接入方式

第三方源通过实现 `Sources/Adapter/LyricsSourceAdapter` 协议以插件形式接入：

```swift
public protocol LyricsSourceAdapter {
    var id: SourceID { get }
    var supportsSyllableSync: Bool { get }
    func search(_ track: TrackRef) async throws -> [SourceCandidate]
    func fetch(_ candidate: SourceCandidate) async throws -> LyricsData
}
```

## 责任归属

- 插件的接口调用行为、鉴权方式、合规性与法律责任**由插件作者自行承担**；
- 核心仓库仅提供协议抽象与加载位，不对任何插件行为负责；
- 用户启用插件即代表自行承担相应风险。
