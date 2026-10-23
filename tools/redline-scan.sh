#!/bin/bash
# F0-6 红线扫描（D53）：push 前门禁——目录红线 / 凭据 / 命名门禁（D47）。
# 用法: tools/redline-scan.sh [扫描根目录，默认 git 暂存区内容] ；命中即非零退出。
set -u
ROOT="${1:-.}"
FAIL=0

# ① 目录红线（任何情况不入公开仓）
echo "① 目录红线:"
for dir in reference research prompts director patch docs/acceptance/logs; do
  if [ -d "$ROOT/$dir" ]; then
    echo "  ✗ 命中禁入目录: $dir"; FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "  ✓ 0 命中"

# ② 凭据扫描
echo "② 凭据扫描:"
CRED=$(grep -rEl --exclude-dir=.build 'ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN (RSA|EC|OPENSSH)? ?PRIVATE KEY|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}' "$ROOT" 2>/dev/null | grep -v "tools/redline-scan.sh" | head -5)
if [ -n "$CRED" ]; then echo "  ✗ 疑似凭据: $CRED"; FAIL=1; else echo "  ✓ 0 命中"; fi

# ③ 命名门禁（D47：产品名/UA/Bundle 禁含工作名；格式类型名放行）
echo "③ 命名门禁（D47）:"
HIT=$(grep -rEl 'Lyricify' "$ROOT" 2>/dev/null \
  | xargs grep -lE 'JustLyric|versionPlaceholder|CFBundleIdentifier|CFBundleName|User-Agent|userAgent' 2>/dev/null \
  | xargs grep -l 'Lyricify' 2>/dev/null \
  | xargs grep -nE 'JustLyric[^"]*Lyricify|Lyricify[^"]*(app|App|UA|Bundle)|versionPlaceholder.*Lyricify' 2>/dev/null | grep -vE 'LyricifySyllable|LyricifyLines|LyricifyFormat' | head -5)
if [ -n "$HIT" ]; then echo "  ✗ 命名违规: $HIT"; FAIL=1; else echo "  ✓ 0 命中"; fi

echo "---"
[ $FAIL -eq 0 ] && echo "红线扫描：通过（可 push）" || echo "红线扫描：命中——禁止 push"
exit $FAIL
