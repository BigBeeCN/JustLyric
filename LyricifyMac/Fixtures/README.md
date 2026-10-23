# Fixtures — 歌词测试夹具（S1 §6）

## 合成文本硬性要求（S7 D7）

**本目录全部文本必须为自造合成文本**（如 `Line one alpha` / `第二行乙` / `Word gamma delta`），
严禁摘录任何真实歌词——包括公有领域歌曲的现行录音版歌词，避免来源争议。
时间戳/结构可以模仿真实形态（如 `[00:12.34]`、词块偏移），文本必须原创。

## 文件清单（S1 §6）

| 文件 | 覆盖点 |
|---|---|
| `lrc_basic.lrc` | 属性行 + 多时间戳行 + 中文 |
| `krc_word.krc` | 2 行逐字 + 元信息头 |
| `qrc_word.qrc` | 2 行逐字 |
| `yrc_word.yrc` | 2 行逐字 + credits JSON 行 |
| `ttml_basic.ttml` | 1 行 2 词 + 翻译 span |
| `musixmatch_richsync.json` | richsync 行数组 |
| `spotify_colorlyrics.json` | lines/syllables/alternatives |
| `lyricify_syllable.txt` | 主行+副行（[3] 与 [6]） |
| `lyricify_lines.txt` | `[type:LyricifyLines]` + 行形态 |
| `instrumental.txt` | `纯音乐，请欣赏` |

## golden 规范（S7 D8）

每份夹具配 `.golden.json`（`LyricsData` 序列化）：camelCase、`sortedKeys + prettyPrinted`、
时间一律 Int 毫秒、`nil` 字段省略（`encodeIfPresent`）。golden 生成后须人工核对锁定（T1.22b）。
