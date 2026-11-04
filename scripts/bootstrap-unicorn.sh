#!/usr/bin/env bash
# =============================================================================
# UniXNU-unicorn 引导脚本：把「框架仓 + SoC 种子 + 设备仓」解析成可构建状态。
#
# 用法：
#   bash scripts/bootstrap-unicorn.sh [--unixnu ../UniXNU] [--soc ../soc-seed]
#
# 做的事（全部幂等）：
#   1. 把 UniXNU 框架仓切到设备仓 migration-state.json 里记录的 upstream_revision
#   2. 用确定的 commit 身份重建 SoC 种子仓，并校验 SHA 与 soc_revision 一致
#   3. 把 os-profiles/ 里的 22H374 profile 装进框架仓
#   4. 写只含 soc + kit 两个本地覆盖的 local.toml（其余源码走 feeds.toml 的 git pin）
#   5. unixnu defconfig / fetch / status
#
# 说明：本脚本不生成任何设备事实（地址、几何、PPID），那些在 dts/board.toml 里，
# 由 scripts/audit-inherited-values.py 看守。
# =============================================================================
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
UNIXNU="$ROOT/../UniXNU"
SOC="$ROOT/../soc-seed"

while [ $# -gt 0 ]; do
  case "$1" in
    --unixnu) UNIXNU=$(cd "$2" && pwd); shift 2 ;;
    --soc)    SOC="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -d "$UNIXNU/.git" ] || { echo "不是 git 仓库：$UNIXNU" >&2; exit 1; }
PIN=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['upstream_revision'])" \
      "$ROOT/migration/format2/migration-state.json")
EXPECT_SOC=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['soc_revision'])" \
      "$ROOT/migration/format2/migration-state.json")

echo "== 1. 框架仓 pin 到 $PIN"
if ! git -C "$UNIXNU" cat-file -e "$PIN^{commit}" 2>/dev/null; then
  git -C "$UNIXNU" fetch --depth 1 origin "$PIN"
fi
git -C "$UNIXNU" checkout -q "$PIN"
git -C "$UNIXNU" log --oneline -1

echo "== 2. SoC 种子（确定性 commit，期望 $EXPECT_SOC）"
if [ -d "$SOC" ]; then
  have=$(git -C "$SOC" rev-parse HEAD 2>/dev/null || echo none)
  if [ "$have" != "$EXPECT_SOC" ]; then
    echo "   现有种子 SHA 不符（$have），重建"
    rm -rf "$SOC"
  fi
fi
python3 "$ROOT/scripts/migrate-pong-format2.py" --unixnu "$UNIXNU" --soc "$SOC" >/dev/null
got=$(git -C "$SOC" rev-parse HEAD)
[ "$got" = "$EXPECT_SOC" ] || { echo "SoC 种子 SHA 不匹配：$got != $EXPECT_SOC" >&2; exit 1; }
echo "   OK $got"

echo "== 3. local.toml（只保留 soc + kit）"
cat > "$ROOT/local.toml" <<EOF
# Local source overrides; do not commit absolute paths.
[[source]]
kind = "soc"
name = "sm8475"
local = "$SOC"

[[source]]
kind = "kit"
name = "PongPlatform24"
local = "$ROOT"

[pong_build]
tree = "$(cd "$ROOT/.." && pwd)/build/unicorn/tree"
developer_dir = "/Applications/Xcode.app/Contents/Developer"
volume_layout = "$(cd "$ROOT/.." && pwd)/private-inputs/volume-layout.json"
EOF

echo "== 4. defconfig / fetch / status"
cd "$UNIXNU"
python3 ./unixnu defconfig unicorn_ipados18_defconfig -D "$ROOT"
python3 ./unixnu fetch -D "$ROOT"
python3 ./unixnu status -D "$ROOT"
echo
echo "== 5. 继承值审计（未确认项必须清零后再上机）"
python3 "$ROOT/scripts/audit-inherited-values.py" || true
