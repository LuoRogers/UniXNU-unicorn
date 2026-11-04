#!/usr/bin/env bash
# 让框架通用的内核脚本使用本板的机器配置
#
# 背景：UniXNU 的 scripts/build-xnu-4k-baseline.sh 里 installhdrs 与最终 make 两步都写死了
# MACHINE_CONFIGS=BCM2837（树莓派的机器配置）。本板（unicorn / SM8475）的 Darwin 24 聚合
# 必须用 MACHINE_CONFIGS=PONG —— config/MASTER.arm64.pong 是由
# patches/xnu-ipados18/0001-pong-darwin24.patch 加进 XNU 源码的。
#
# 不改这一处会直接失败：
#   make[1]: *** [build_setup_bootstrap_DEVELOPMENT^ARM64^BCM2837] Error 2
#   make: *** [installhdrs] Error 2
#   *** Unsupported CURRENT_MACHINE_CONFIG BCM2837
#
# 用法（在 UniXNU 检出目录里执行）：
#   bash <device>/scripts/pin-baseline-machine-config.sh ../UniXNU
set -euo pipefail

UNIXNU_DIR=${1:-../UniXNU}
SCRIPT="$UNIXNU_DIR/scripts/build-xnu-4k-baseline.sh"

[ -f "$SCRIPT" ] || { echo "找不到 $SCRIPT" >&2; exit 1; }

before=$(grep -c 'MACHINE_CONFIGS=BCM2837' "$SCRIPT" || true)
echo "== 修改前 MACHINE_CONFIGS=BCM2837 出现 $before 处 =="

if [ "$before" = "0" ]; then
  echo "已经是 PONG 或无需修改"
  exit 0
fi

# macOS(BSD sed) 与 GNU sed 的 -i 语义不同，用临时文件方式最稳
tmp=$(mktemp)
sed 's/MACHINE_CONFIGS=BCM2837/MACHINE_CONFIGS=PONG/g' "$SCRIPT" > "$tmp"
mv "$tmp" "$SCRIPT"
chmod +x "$SCRIPT"

after=$(grep -c 'MACHINE_CONFIGS=BCM2837' "$SCRIPT" || true)
pong=$(grep -c 'MACHINE_CONFIGS=PONG' "$SCRIPT" || true)
echo "== 修改后：BCM2837 剩 $after 处，PONG 有 $pong 处 =="
[ "$after" = "0" ] || { echo "仍有残留，请检查" >&2; exit 1; }
grep -n 'MACHINE_CONFIGS=PONG' "$SCRIPT" | head -5
echo "OK"
