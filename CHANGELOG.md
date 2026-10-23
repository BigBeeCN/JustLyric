# CHANGELOG

## [Unreleased]

### M1 · LyricsCore

#### 2024-…-… 规格同步 v3（UPDATE-S7 增量包，D12–D16）
- 应用 `patch/UPDATE-S7-增量包.md`：S7 正文更新至 D1–D16（附录 A/B 按 D12 不入 S7）；
- S1 §2.4/§2.7 按 D13 改写（YRC credits `tx/li/or`；Spotify 无 `char`、`numChars` 切词、字符串毫秒）；
- prompts/P5 金标准算例节按附录 A 整体替换；夹具修正：`yrc_word.yrc`（ty→tx 最小化）、
  `spotify_colorlyrics.json`（D13 schema）；任务卡升 v0.3（D12 授权 Agent 维护映射表）。

#### 2024-…-… 规格同步（FULL-SYNC 全量包）
- 解包 `patch/FULL-SYNC-全量包.md` → README.md、spec/S0–S7、prompts/P0–P5；
- 变更：README（+S7 索引）、S1（翻译挂载 D6、AppleJson 注 D1、判型/解析双轨 D9、夹具/golden 规范 D7/D8）、
  S2（acoustic 档位 D2、positionalMatch D3、CompareArtist 单档位 D4、OpenCC 词组级 D5、romaji 占位 D10、attachTranslation D6）；
  S0/S3–S6/prompts 无变化；新增 `spec/S7-决策记录.md`（D1–D11）；
- 任务卡 v0.1 → v0.2（S7 映射更新，`docs/tasks/M1-LyricsCore-任务卡.md`）；决策日志落盘 `docs/decisions.md`。

#### T1.00 工程脚手架（完成）
- `LyricifyMac/Package.swift`（swift-tools 5.10 / macOS 14，5 target + 2 test target，依赖单向）；
- `.swiftformat`；Fixtures/ 目录 + D7 合成文本声明；空壳 target 可编译零警告（clean build 验证 0 warning/0 error，`swift test` 2/2 绿）。

#### T1.22a 夹具撰写（完成）
- 10 份合成夹具落库 `LyricifyMac/Fixtures/`（S1 §6 结构、S7 D7 全合成文本）；
- 附加假设 A8（Spotify syllables/alternatives/colors 与 YRC credits 元素字段按 spec 字面构造）→ 已由 D13 裁定并修正。

#### T1.01 领域模型（完成）
- `Sources/LyricsCore/Model/`：SyncLevel/LyricsAlignment/LyricsRawType(D1 定案 10 case)/Syllable/LyricsLine/LyricsData/TrackRef；
- Codable 全支持（camelCase、sortedKeys+prettyPrinted、nil 省略，S7 D8）；DocC 全覆盖；测试 4/4 绿。

#### T1.02 类型判别 detectType（完成）
- S1 §3 七正则逐字符移植（Compiled 语义）；判定顺序 JSON→XML→LyricifyLines 标记→KRC→YRC→LyricifySyl→QRC→LyricifyLines 行形态→LRC→Unknown；
- 含 BOM/CRLF 脏输入容忍、D9 负例（A9 待批形态）；测试 7/7 绿。

#### T1.16 归一化 + LCS + 繁简引擎（完成）
- `NormalizeName`/`ComputeTextSame`（S2 §2.2 步骤 1/9）；
- D15 选型落地：自研词组级合并引擎（短语优先最长匹配）+ OpenCC 官方词典 8 部（Apache-2.0，随包+LICENSE）；
- 词组级证据：乾元/壺裏乾坤/乾乾淨淨；s2twp（软件→軟體）/s2hk（里→裏；丹尼·博伊尔→丹尼·波爾）；测试 11/11 绿。

#### 裁定入档（D17–D19）
- D17：A1–A7 追认（A1 附加 title≤前 3 行/ending≤后 3 行；A5 注明“正值=延后”）；
- D18：A9 追认（LyricifyLines 行形态推导式 + D9 负例入回归）；
- D19：A10 部分否决——alternatives 不映射行字段、原样存 `additionalInfo`，禁挂 subLine/isBackgroundVocal；
  T1.09 任务卡先改后写；模型增 `SpotifyAdditionalInfo`/`SpotifySyncType`/`LyricsData.additionalInfo`。

#### 波次 2：全部解析器 + 工具（完成，T1.03 → T1.04–T1.10 → T1.14/15）
- T1.03 LrcParser（D9 宽容时间戳/A9 四位截断、D6 行后缀默认关）；
- T1.04 KrcParser（元信息剥离、块前文本后）；T1.05 QrcParser+XML 大包；T1.06 YrcParser（D13 credits tx→writer）；
- T1.07 TTMLParser（三种时间格式、p 直接文本兕底）；T1.08 RichSyncParser（A6 舍入、subtitle_body 转发）；
- T1.09 SpotifyLyricsParser（D19 语义、numChars 切词、endTime==0 无时序、A2 双形态）；
- T1.10 LyricifySyllable/Lines（[3]–[8] 映射、subLine、括号行）；
- T1.14 LyricsUtilities（detectCJK/applyOffset/downgrade/isInstrumental 4 文案）；
- T1.15 SentenceSplitter（maxChars=24、时间守恒、A4 翻译分配）；
- 新增测试 33 项；累计 `swift test` **56/56 绿**，clean build 0 警告 0 错误。

#### 裁定入档（D20–D21）
- D20：A11 部分否决——新增 `trackMeta{title,artists,album,durationMs}`（ti/ar/al/length 全映射）；
  TTML agent role=l/c→writer、artist/vocalist→trackMeta.artists；Unknown→纯文本行（D21 `.unsynced`）；
- D21：`SyncLevel` 扩三值（unsynced/lineSynced/syllableSynced）；S1 §1 同步改写；SpotifySyncType 追认。

#### 泯次 3：T1.11 → T1.12/13 → T1.17/18/19 → T1.20 → T1.21/22b/23（完成，M1 收官）
- T1.11 parse 分发（.unknown 纯文本兜底）；T1.12/13 六生成器（A3 `mm:ss.xxx`、SubLinesOutputMode）；
- T1.17/18/19 匹配引擎（D2/D3/D4/D14 全量；P5 金标准例 1–4 断言入库）；
- T1.20/21 优化管线 1–9（D17 A1 约束、D6 attachTranslation、D10 romaji 占位）；
- T1.22b golden 10 份（D8 规范，人工核对锁定）+ round-trip harness；
- T1.23 验收报告 → `docs/acceptance/M1-report.md`（S6 §2 逐条 ✔）。

**M1 完成：`swift test` 103/103 绿，clean build 0 警告 0 错误。**

#### T1.17 返工（D23/D24，完成）
- D24：DashToParen 字面移植 `T(s)=(s.Replace(" - "," (").Trim()+")")` 无条件补 `)`；
  钉死回归：`Song - Live` vs `Song (Live)` → **High**（LCS 81.8%），禁止"顺手修正"；
- D23：SingleSpecial=双边 `(feat` 基名相等 → High；SpecialCompare=恰单边（双边均带不命中）；
  新增回归：`Song (feat A)` vs `Song (feat B)` → High + 双边均带负例断言；
- D22：显式标记集 🅴/Ⓔ 追认；脏话掩码表另立任务卡（积压）；
- 累计 **104/104 绿**。

#### M2 任务卡拆分（已确认，v0.2）
- `docs/tasks/M2-任务卡.md`：17 卡（Sources 8 + MediaSession 8 + 真机验收 1），含合规红线标注（P1/P2）与 P5 真机验收介入（S3 §8 + S6 §5）；D25 五条补充已并入（schema 迁移/lyricsUpgrade+quality/公证验收/手测清单/脏话掩码排 M5）。

#### M2 波次 0（完成）：T2.01 + T2.02
- T2.01 源适配协议层：`LyricsSourceAdapter`/`SourceCandidate`/`SourceID`/`SourcePreferences`/`LyricsQuality`（D25 #2 quality 档）；
  修复 `TrackRef` 显式 `Sendable`（消除跨模块 Sendable 警告）；测试 4/4；
- T2.02 `Sources/Plugins/README.md` 合规声明（五家受限源名单 + 责任归属）；
- 红线自查：代码零受限源端点/域名（仅 DocC 红线注释提及名单）；`swift test` **108/108 绿**，clean build 0 警告。

#### M2 波次 1（完成）：T2.03 + T2.04 + T2.05 + T2.10（D26 预钉全量吸收）
- T2.03 LRCLIBAdapter：UA 头/三端点/`instrumental`+`plainLyrics`+无结果映射（D26 #1/#2）；
- T2.04 AppleTTMLAdapter（红线卡）：TokenStore（Keychain 必测过）、双端点（amp-api + ttml-internal 兜底）、
  信封解包后丢弃（D26 #4）、401→isTokenExpired、2xx 空=noResult；红线自查全过；
- T2.05 LocalFilesAdapter：文件名三模式兜底（D26 #3）、`(Live)` 标记保留、D6 副文件配对→attachTranslation、FileWatcher；
- T2.10 MediaEvent/SessionInfo/MediaSource/NowPlayingAggregator（D26 #5：顺序契约、focusedChanged 快照、
  同曲防抖 ≤300ms 不跨曲合并）；新增 MediaSessionTests target；
- 顺带补 `TrackRef: Equatable`；累计 `swift test` **127/127 绿**，clean build 0 警告。
- 待批 A17（常数/字段名/端点模板，D16 硬规则）：LRCLIB UA 占位、amp-api 信封 payload 字段名 + search 端点、
  去抖 300ms/遮罩规则/接受规则、MediaSnapshot 字段名。

#### D27（A17 裁定）+ T2.04 修订（完成）
- D27 #1：UA 单点 `UserAgent.swift`（占位不得出正式构建 → P5 发版检查项）；
- D27 #2：信封主路径 `syllable-lyrics` → 回退 `lyrics` → 递归最后兜底；`ttmlLocalizations` 忽略；
  端点定案（歌曲详情/搜索/storefront `/v1/me/storefront`）+ Referer/Origin；双路径用例补测；
- D27 #3/#4：常数/字段名追认，此类免报。

#### M2 波次 2（完成）：T2.06 + T2.07 + T2.20 + T2.24
- T2.06 LyricsCache（SQLite）：六列 schema 定案 + `PRAGMA user_version` 顺序迁移（D25 #1）+ CacheKey；
- T2.07 RetryPolicy（1s/2s/4s×3、Retry-After）+ CircuitBreaker（5 败/60s，时钟注入）；
- T2.20 MediaRemoteShim（红线卡 ★）：单文件 dlopen+dlsym、四符号探测、优雅降级演练绿；
  **实测：开发机直接调用猜测签名触发 SIGTRAP**（A18 待批：C 签名规格空白，调用校准划归 T2.30 真机）；
- T2.24 SessionRules + SessionPolicy（首方规则表/未知 app 询问状态机）；
- 累计 `swift test` **143/143 绿**，clean build 0 警告；T2.20 红线自查：符号名全仓仅 shim 一处 ✓。

#### D28（A18 裁定）+ 泯次 3（完成）
- D28：MediaRemote 签名定案（五符号）；SIGTRAP 两诱因落防（Boolean→UInt8、kMR… 解引用）；
  单一 callGuard（超时/异常即降级）；Unregister 补齐；单测仍只探测/降级；
- T2.08 LyricsProvider：真竞速（完成序）+ `lyricsUpgrade` 热替换（D25 #2）+ quality 标记 +
  缓存联动 + T1.19 CandidateRanker 泛型排序接入 + 熔断联动；
- T2.21 直连源（Music/Spotify ScriptRunner 抽象）+ 分发通知源 + 直连优先规则；
- T2.22 TimelineProvider：250/1000ms 三分支软校正（α=0.2）、字面推算公式、暂停冻结/倍速、
  forceInternalTimer、120Hz 插值（S6 §3-2/-3 全覆盖）；
- 累计 `swift test` **160/160 绿**，clean build 0 警告。

#### D29（波次 4 预钉）+ 泯次 4（完成）：T2.25 + T2.26 + T2.27
- D29 #1：四层延迟同 A5（正值=延后）求和可为负；蓝牙判定 `kAudioDeviceTransportTypeBluetooth`；
  +150ms 仅 UI 预填、`confirmSuggestion` 用户确认后写入（不自动生效）；S6 §3-4 构造表断言 ✔
- D29 #2：封面 LRU 默认 200（键=TrackKeying 单点）；清洗（去 `(feat. …)`/`【…】`、全角归一、
  艺术家拆分 ,/、/&/x）；T2.27 权限与降级（directOnly 状态机、Automation 引导、诊断快照 S5 §4）；
- D29 #3：T2.30 证据四件套已入卡；累计 `swift test` **171/171 绿**，clean build 0 警告。

#### D30（M3 预钉）+ M3 泯次 0（完成）
- D30 六项入档；M3 任务卡 `docs/tasks/M3-任务卡.md` 落盘（波次 0–3 + S6 §4 映射）；
- `TimelineProviding` 协议落 LyricsCore（D30 #5：组件只认协议、禁直读系统时钟；依赖方向
  RenderKit→LyricsCore、MediaSession 仅做符合声明）；
- KaraokeStyle（D30 #3 MVP 默认：floatHeight=2/progressWidth=8/unplayedOpacity=0.55/fillSoftness=1）；
- FillGeometry（D30 #1：词内线性、词宽缓存、行级线性、边界钳制）；
- KaraokeTextView（两文本层 + mask 裁剪；逐帧只动 mask（relayoutCount 回归）；D30 #6 填充域无 CA 曲线）；
- 累计 `swift test` **180/180 绿**，clean build 0 警告。
- T2.30：**环境等待中**（委托方备 Spotify/Apple Music/浏览器/蓝牙；可选 devToken/MUT）。

#### D31（T2.30 环境方案调整）+ M3 泯次 1（完成）
- D31：网易云顶替 Apple Music 作"任意播放器"样本；MusicSource/AppleTTML 真机项 skipped（单测证据替代）；
  核心必测=Spotify 直连+MediaRemote 全 app 路径；负例预案；网易云播放器接入合规澄清（红线仅限歌词源）；
  TimelineProviding 架构决策追认；
- M3-1 WordShineEffect（D30 #2：0.6/1.0/1.4、模糊 2/4/8pt 随字号缩放、进 120ms/出 240ms 三档一致、
  ReduceMotion 关闭）；
- M3-2 七行为规划器（S4 §3）+ CubicBezier + SpringTimingMapper + LineScrollerView（CA spring 域，
  D30 #6 域分离）；ReduceMotion 退化为纯透明度（S6 §4 无位移动画断言）；
- 累计 `swift test` **193/193 绿**，clean build 0 警告。

#### T2.30 启动（进行中）
- 证据①：`nm -gU` 不适用（二进制仅存 dyld 共享缓存），以 dlsym 等价核验补位——五符号全解析；
- 证据②：真机调用复现 SIGTRAP 并定位 **第三桥接陷阱**（`@noescape` 块逃逸），
  `@escaping` 修复后五调用全安全；回归 193/193；notarized 日志待发版补测；
- `M2Probe` 采集工装落库（symbols/calibrate/snapshot/drift/listen/lyrics）；
- `docs/acceptance/M2-report.md` 骨架落盘；播放驱动项待播放会话。

#### D32（F1 条件通过/第三陷阱钉表/Spike 立卡）+ M3 泯次 2（完成）
- D32 三条件落实（代码路径保留、报告附 F1 证据、UI 模式显示入 M4 备忘）；
  SIGTRAP 诱因表（三陷阱）固化为 MediaRemoteShim 必读注释；Spike-1/2 立卡 `docs/tasks/T2.30-Spikes.md`；
- 快照架（自研 CG，D15 备案）：SnapshotRenderer + 基准（D30 #4）+ 矩阵 6 状态 × dark/light 12 基线；
  同机零抖动判定 ✔（确定性测试）；状态可区分 ✔；
- 组件组：BreathingDots/MarqueeText/AdaptiveText（拟合纯函数）/DuetLayout；
  FrameBudget 基准入测（tick 平均 <8ms 预算 + 帧内零重排断言）；
- 累计 `swift test` **201/201 绿**，clean build 0 警告。

#### D33（M3 泯次 3 预钉）+ M3 泯次 3（完成）
- D33 #1 取色：KMeans-Lab（Lab/簇 6/迭代 ≤10/忽略 <1%）+ OctTree 快速路径；
  主色=最大簇均值、辅色=次大簇 ΔE>12、不足补同色相明度变体（全规则单测）；
- D33 #2 抖动：蓝噪声 64×64 平铺、±1 LSB、开关可关（单测）；
- D33 #3 背景帧率：默认 24（≤30）、efficiency 0.5/15fps（单测）；
- D33 #4 三套样式默认（24 Bold / 22+16 副行 70% / karaoke+D30#3）+ 阴影 black/0.5/8/2/270° + 描边默认关；
- D33 #5 快照重录规则入流程（本波次样式默认未接入快照基线，无需重录；接入时按规则重录+目检）；
- ArtworkView（封面进入 spring；ReduceMotion 仅淡入）；修复：`PixelRGB` 重命名（撞 Carbon `RGBColor`）；
- Spike-1 初测两轮（终端代持 / 内嵌 Info.plist ad-hoc）：MediaRemote 仍空——待用户确认授权弹窗情况；
- 累计 `swift test` **211/211 绿**，clean build 0 警告。

#### T2.30 收口（M2 终版报告交付）
- Spike-1 证伪（权限已授+bundle 身份仍空读数）；Spike-2（AX 通道）排 M3/M4；
- 证据③：有效段 22.5s 净偏 -12.9ms、抖动 ±14ms、无系统性漂移趋势；60min 长跑列 P5 仪表项；
- 过程缺陷修复：NSAppleScript 并发静默失败（生产串行队列化）、切歌位置回卷重置基准；
- M2 终版报告：`docs/acceptance/M2-report.md`（✔5 项 / 🟡2 项 / ⚠️2 项 / skipped1）→ 待终验。

#### D34（M2 终验通过）+ M3 收口（完成）
- D34：#9/#2 条件接受（60min 长跑 + 1s 目测迁 M4 门禁，不得删除）；M4 门禁三条入卡；
- 守则落盘 `docs/TEAM-RULES.md`（虚构 API/字面移植/脚本串行/假设分流/红线）；
- D34 串行规则：≥50 并发压力用例常驻（60 并发全过）；
- M3 收口：样式面接线（三套预设入快照矩阵）→ D33 #5 重录 14 基线 → 人工目检 ✔；
  修复 AppKit 离屏第三坑（视图挂载子层惰性→递归视图树渲染）；
- `docs/acceptance/M3-report.md` 交付（S6 §4 4/4 ✔、D30/D33 预钉 11/11 ✔）；
- 累计 `swift test` **212/212 绿**，clean build 0 警告。

#### D35（M3 收口通过）+ 双线推进
- Spike-2 突破：CGWindowList 窗口名通道可用（Spotify 标题=艺人-曲名全量元数据）；
  AX 通道 -25205；待网易云/YouTube 样本定分支（M4 门禁③）；
- M4 任务卡 `docs/tasks/M4-任务卡.md` 落盘（12 卡 + D35 五域预钉 + ⭐设置默认值总则）；
- M5 积账确认：脏话掩码表/AnimatedClock/60min 长跑 + 1s 目测。

#### Spike-2 结案（M4 门禁③ 结论出）
- 结论：**部分可用→支持清单**（Spotify 直连+标题 / Apple Music 直连 / 浏览器活动标签）；
- 负样本实证：网易云双通道标题恒空、浏览器后台标签不可得 → 文案不得宣传"全 app"；
- 标题解析规则定稿（M4-01/02 接线依据）；AX 属性名教训（`AXWindows`/`AXTitle` 非 `kAX*` 常量名）。

#### Spike-3 告破（M2 门禁③ 结论升级）🏆
- 根因：mediaremoted 宿主信任位（平台二进制 entitlements=512 放行；Ad-hoc=0 → Operation not permitted）；
- 实证：**原创 C adapter + perl 宿主**同刻读到网易云全量元数据（title/artist/album/duration/elapsed）；
- 技术路线定稿：自研 dylib + 自研 perl 宿主 + JSON 流（App spawn 助手）；
- 支持清单修订候选提请 D37（MediaRemote 全 app 分支复活）。

#### D37 落实 + adapter 转正（完成）
- 架构四项强制落地：符号单点 adapter.c（QA 扫描 ✓ 仅一处）、AdapterHost 协议（perl 弃用对冲，
  备选 Widget/JXA 预研位）、降级链保留（直连>窗口标题）、常驻流式/单查缓存<100ms/重启防抖 60s；
- 产品形态端到端验证 ✔：repo dylib + repo perl 宿主直读全量元数据（Raindance/Dave/Tems…）；
- MediaRemoteShim 重写为宿主客户端（零 MediaRemote 符号）；文案上限/禁词入卡；
- M4-12 补充验收卡立卡（三样本满载 + <300ms + 60min 并跑）；M4-01/02 通道表改写，网易云转正；
- 累计 `swift test` **216/216 绿**，clean build 0 警告。

#### D38 落实 + M4-00 开工（完成）
- D38：拆分器防扩张——`/` 不拆（AC/DC、Dave/Tems 反例测试入库）；守则 #0 置顶（市场证据优先）+ #7 新增；
- M4-00 设置基座 ⭐：SettingsModel（7 组 MVP 键 + 解码全兜底）+ SettingsStore（原子写）
  + SettingsMigrator（version/顺序迁移）；缺键回退组件默认（D30#3/D33#4 断言）禁崩；
- AppTests 目标启用；累计 `swift test` **222/222 绿**，clean build 0 警告。

#### M4-01/02 显示面波次（完成）
- M4-01 菜单栏：内容=曲名-歌手、MarqueeText 复用（扩展 dwell 参数，30pt/s+1.5s 驻留，
  D35 时序单测）、迷你面板点弹/ESC 关；
- M4-02 灵动条：布局常数 24/36/18/≤60%（逐项断言）、byland 状态机（贴边半隐藏⇄悬停展开，
  0.8s 退出防抖、悬停中不收起边界、snap 强制回贴边）；状态图随验收报告附上；
- NSPanel 无 cornerRadius（挂 contentView 层）记录；累计 `swift test` **227/227 绿**。

#### D39（byland 定案）+ M4-03/04（完成）
- D39：byland=贴顶缘+露出 1/2；四缘吸附列 M5（键位预留）；边界四条固化基线；
  流程注记入守则 #2（实现与已定规格语义不一致先报再做，下不为例）；
- M4-03 全屏：D35 默认（底部细条/缩放 1.0/AdaptiveText 0.5×）+ IOPMAssertion 防休眠；
- M4-04 桌面窗：PanelBehavior 纯规则（锁定穿透/双击编辑/5s 自动隐藏/全屏隐藏）
  + EdgeSnap 吸附 + DesktopPanel（nonactivating⇄编辑态焦点转换）；
- 三处 API 磨合记录：fullScreenContentView 不存在、IOPM 需 pwr_mgt 子模块、NSPanel 无 cornerRadius；
- 累计 `swift test` **235/235 绿**，clean build 0 警告。

#### M4-05 系统集成（完成）
- 热键：D35 默认不绑定（defaultBindings 断言为空）；HotkeyRecorder 状态机
  （录制/超时 10s/取消/冲突拒收/功能键免修饰）；Carbon 注册簿记 + 真机验证归 M4-11；
- 单实例（NSRunningApplication）、自启（SMAppService）、睡眠策略
  （prevent_sleep_fullscreen_only 语义单测）；
- 累计 `swift test` **239/239 绿**，clean build 0 警告。

#### D40 + M4-06/07/08（完成）
- D40：A15 两级落地——录制器接系统拒止清单（"系统保留"原因 + 用户覆盖否决权默认禁止）；
  拒止清单 v1 草案出稿（D40 点名最小集 11 条，不自行扩大）→ 待二次报批；
- M4-06 SessionSettingsViewModel（未知 app 询问/记忆、kind 落 SessionEntry）；
- M4-07 LatencyCalibrator（+150ms 预填→确认写入 D29 #1、跟拍测试器）；
- M4-08 SourceSettingsViewModel（SourcePreferences 桥接、SourceID(identifier:) 还原、目录校验）；
- 累计 `swift test` **244/244 绿**，clean build 0 警告。

#### D41（拒止清单固化）+ M4-10 组装（完成）
- D41：清单 11 条固化（断言锁死为变更唯一门禁，扩表需新裁定）；
- M4-10：AppCoordinator 总装（设置/窗口/生命周期/引导/日志）+ WindowManager 显示面独立开关
  +记忆（S6 §5 模块级）+ PermissionPrompt 推导（S3 §7）+ 单实例决策；
- 入口壳 LyricifyMacApp（@main 独立 executable，S7 A7：App target 保持 library 零分歧）；
- 累计 `swift test` **248/248 绿**，clean build 0 警告。

#### M4-12 演练（手动段完成）+ 证据包落盘
- 三样本满载断言 ✔（Spotify 双路互证 / 网易云 9 首 / 浏览器 YouTube），后台标签疑似正样本待复核；
- 事件时延：双路对照样本量化（274ms/920ms 通道差）；adapter 轮询 400ms→150ms 预算修正；
- 漂移：短窗读数交付；60min 长跑改**无值守补跑**（门禁①保留不得删除）；
- `docs/acceptance/M4-report.md` 证据包落盘。

#### D42（M4-12 收口裁定）+ M5 积账评估
- D42 三裁定入档：时延口径（最坏通道上界 240ms ✔，通道差记录不修正）、后台标签三条件复核判据、
  长跑"开跑"口令制（M4-11 收数后执行）；
- M4 证据包补 D42 口径与复核判据；
- M5 积账评估落盘（9 项/四波次：脏话掩码表→AnimatedClock/四缘吸附→分享/备份/通知驱动→Sparkle/性能/发版）。

#### M5 波次 1：脏话掩码表（完成）
- `ExplicitClean` 落库 LyricsCore：**双方向分离**（fix 还原 28 条正则表 / clean 掩码
  strong=还原后整词全星号、weak=保留首尾字母）+ 独立词上下文掩码（ass/Ass/hoe 边界判定，
  classic/pass 不误伤）；
- 对照 research/Explicit.cs 实测清单事实移植（28 条替换表、strong 语义）；代码原创；
- 累计 `swift test` **253/253 绿**，clean build 0 警告。

#### 60min 长跑收数 + M4-11 验收报告
- 窗口 14:09–15:09 整 60 分钟、22 曲自然播放；段级漂移 22 样本（均值 −94.7ms、
  标准差 257.8ms、峰值 625.9ms）——源侧口径（elapsed 事件驱动实证：4s 三查恒陈旧）；
- 门禁①数据交付+口径限定（提请终验裁定终形态）；门禁② UI 目测待 M4 手测窗；
  门禁③文案核对通过；后台标签三条件缺③维持"疑似"。

#### D43 落实：TimelineProvider 加固（产品级）+ 条件③准备
- D43 #3 陈旧样本防御落地：rate>0 且连续样本 elapsed 不变、墙钟前进 → 标记陈旧，
  不参与软校正、绝不触发 seek；仅 rate 变化/暂停/恢复重置基准；回归"陈旧序列不得拉动时钟"入库；
- 附带产品修复：首样本（含状态重置后）仅立基准不作 seek（seek=播放中跳变语义）；
- D43 #2：adapter 载荷补 pid（实测 pid=55056 网易云入账）；录制数据缺 pid → 手测窗补 30s 复测；
- 累计 `swift test` **254/254 绿**，clean build 0 警告。

#### M4 手测窗 + M4-11 终版（收口）
- 门禁② 1s 目测 ✔（实测通过）；门禁①录屏入档；门禁③文案 ✔；
- **D37 #2 关闭**：后台标签三条件坐实（pid=51460=Google Chrome）；
- 手测揪出并闭环：歌词超前（延迟校准域，+150ms 校准）、长行截断（wrapsText）、
  行推进 firstIndex 误用、fetch 失败假阴性、宿主持有权丢失——五则修复三则教训入账；
- 累计 `swift test` **254/254 绿**，clean build 0 警告。

#### D46（M4 终验 🏁）+ M5 波次 2（完成）
- D46 制度落地：①"限定语逐字核对"升级强制验收栏（TEAM-RULES #2 + #2b 存在 API 文档约束条）；
  ②校准生产化入积账 #10（发版检查增"旁路清理"）；
- M5-2：AnimatedClockView（数字翻牌、时钟注入、ReduceMotion 直切）+ 灵动条四缘吸附
  （D39 增强：top/bottom/left/right 几何 + 半隐藏露出比 + `island.dock_edge` 键位预留）；
- 首批"限定语逐字核对栏"测试落地（v1 顶缘语义不漂移断言）；
- 累计 `swift test` **262/262 绿**，clean build 0 警告。

#### M5 波次 3（完成）
- **校准生产化（D46 #3 硬项）**：CalibrationService——tap→均值→写入 perDevice/perApp/global
  （A5 正=延后）+ 四层求和生效偏移统一入口（预览/桌面/全屏）；预览窗停用
  LYRICS_PREVIEW_OFFSET_MS 旁路（代码使用点归零，清理归波次 4 发版检查）；
- 分享卡片（S0 §3 合规）：系统字体渲染 + 署名行必含 + QR 码；
- 备份恢复（S5 §2）：export/import JSON 复用 schema 版本+迁移器（D46 提示 #3）；
- 通知驱动优化维持备选（D42）；累计 `swift test` **266/266 绿**，clean build 0 警告。

#### M5 波次 4（发版工程，进行中）
- 性能自动化基准（A2/A4/A5/A6）：缓存命中 <300ms、tick <8ms/帧（60fps 预算双断言）、
  工作集 <300MB——3 项基准测试入库；A1/A7/A8 归发布前真机窗；
- Sparkle 骨架（UpdateSettings/UpdateChecker 抽象，feed URL 随 UA 定稿接入）；
- 发版检查项终扫清单落盘（6 项，预扫 5 项绿：禁裸词 0/旁路 0/红线全绿）；
- **待委托方决策**：UA 定稿（org/repo/产品名，D27 #1 占位 5 处）。

#### D47 命名门禁落地 + UA 定稿
- 产品名 **JustLyric** / 发布 **github.com/BigBeeCN**（repo 暂定 JustLyric）；
- UA 单点定稿 `JustLyric/0.1.0-dev (github.com/BigBeeCN/JustLyric)`；Bundle ID 兜底
  com.bigbeecn.justlyric；IOPM 断言/分享署名/日志/数据目录全数去工作名；
- 发版断言 #1 提前达成（占位 grep=0 + 命名门禁扫描 0 残留；格式标记为 S1 钦定类型名合规保留）；
- 累计 `swift test` **269/269 绿**，clean build 0 警告。

#### D49（endMs 推定上移管线）+ M5 收口 + 全项目 DoD 终验 🏁
- D49：TimeSpanInferrer 入管线步骤 10（缺失→下一行 start→末行 +3000ms→inferredSpans 标记）；
  渲染层禁兜底（断言化）；单调性单测入库；
- M5 收口报告 + DoD 终验报告交付：M1–M5 里程碑全 ✅；通用 DoD 4/5（swiftformat 归发版管线）；
- 委托方复验：时间轴准（A1 ✅）、D48 后逐字首字起扫 ✅、A7/A8 无异常 ✅；
- 终态：`swift test` **270/270 绿**、clean build 0 警告、教训账 9 则+制度 2 条。

#### D50 最终裁定 🏁：全项目 DoD 终验通过
- M1–M5 全里程碑 ✅、合规红线 ✅、通用 DoD 4/5（swiftformat 归 CI 等效）；
- D1–D50 封存；发版门禁 4 项清零中（release-checklist 跟踪）；
- 项目状态：**开发侧完成，发版就绪**——JustLyric 待发版检查项清零后见用户。

#### v0.0.1 正式发布 🚀
- **https://github.com/BigBeeCN/JustLyric/releases/tag/v0.0.1**（tag v0.0.1，ad-hoc 分发）；
- 产物四件套（zip/SHA-256/appcast/INSTALL 自签三法）；README 合规文案（无"精准逐字"宣称，D51 #3）；
- seek 反应实测留痕（同秒刷新）；残项：A1 波形量化补强、门禁①显示侧补强、Sparkle 待正式签名。
