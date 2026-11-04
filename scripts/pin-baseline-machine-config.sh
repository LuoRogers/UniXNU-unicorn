#!/usr/bin/env bash
# 让框架通用的内核脚本能编 darwin24 聚合（本板）
#
# 两处修正（都只改框架的 scripts/build-xnu-4k-baseline.sh，不改 XNU 源码）：
#
# 1. MACHINE_CONFIGS=BCM2837 -> PONG
#    树莓派的机器配置；本板（unicorn / SM8475）必须用 PONG
#    （config/MASTER.arm64.pong 由 patches/xnu-ipados18/0001-pong-darwin24.patch 加入）。
#
# 2. 给 vm_unix.o 打开 -DVM_UNSAFE_TYPES
#    installhdrs 是带 -DVM_UNSAFE_TYPES=1 生成的（导出头里 mach_vm_*_ut 是 union），
#    但内核自身的编译没有这个宏，于是 vm_unix.c 里"普通整型 vs union"12 处不匹配。
#    pong/thor 的官方构法（kits/PongPlatform24/build-support/merged-scripts/build-xnu-ipados18.sh:666）
#    正是**只对 vm_unix.o** 打开这个宏，而不是全局打开（全局会撞上 C++ TU 的
#    "Can't turn on unsafe types in C++" 与其它 TU 的原型冲突）。
#
# 用法（在 UniXNU 检出目录里跑）：
#   bash <device>/scripts/pin-baseline-machine-config.sh ../UniXNU
set -euo pipefail

UNIXNU_DIR=${1:-../UniXNU}
SCRIPT="$UNIXNU_DIR/scripts/build-xnu-4k-baseline.sh"
[ -f "$SCRIPT" ] || { echo "找不到 $SCRIPT" >&2; exit 1; }

tmp=$(mktemp)
python3 - "$SCRIPT" "$tmp" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()

# --- 1. 机器配置 ---
s = s.replace('MACHINE_CONFIGS=BCM2837', 'MACHINE_CONFIGS=PONG')

# --- 2. vm_unix.o 打开 VM_UNSAFE_TYPES ---
# 找到现有的 vm_unix.o_CFLAGS_ADD 追加宏；找不到就补一条。
marker = '-DXNU_OWNER_CACHE_CARRIER='
if 'vm_unix.o_CFLAGS_ADD=-DVM_UNSAFE_TYPES' not in s:
    if marker in s:
        s = re.sub(r'(vm_unix\.o_CFLAGS_ADD=)(?!-DVM_UNSAFE_TYPES)',
                   r'\1-DVM_UNSAFE_TYPES ', s, count=1)
    else:
        # 没有任何 vm_unix.o 条目时，补在 EXTRA_MAKE_ARGS 初始化之后
        s = s.replace('EXTRA_MAKE_ARGS=()',
                      'EXTRA_MAKE_ARGS=()\nEXTRA_MAKE_ARGS+=("vm_unix.o_CFLAGS_ADD=-DVM_UNSAFE_TYPES")', 1)
open(dst, 'w').write(s)
print('patched')
PY
mv "$tmp" "$SCRIPT"
chmod +x "$SCRIPT"

echo "== 校验 =="
bc=$(grep -c 'MACHINE_CONFIGS=BCM2837' "$SCRIPT" || true)
vu=$(grep -c 'vm_unix.o_CFLAGS_ADD=-DVM_UNSAFE_TYPES' "$SCRIPT" || true)
echo "  残留 BCM2837: ${bc}（应为 0）"
echo "  vm_unix.o 已带 -DVM_UNSAFE_TYPES: ${vu}（应为 ≥1）"
grep -n 'vm_unix.o_CFLAGS_ADD' "$SCRIPT" | head -3
[ "$bc" = "0" ] && [ "$vu" -ge 1 ] || { echo "修正不完整" >&2; exit 1; }
echo OK
