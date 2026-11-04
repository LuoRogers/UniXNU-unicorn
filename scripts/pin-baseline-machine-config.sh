#!/usr/bin/env bash
# 让框架通用的内核步骤能编 darwin24 聚合（本板 unicorn / SM8475）
#
# 三处修正，都只改 UniXNU 检出里的脚本，不改 XNU 源码：
#
# 1. scripts/build-xnu-4k-baseline.sh: MACHINE_CONFIGS=BCM2837 -> PONG
#    （config/MASTER.arm64.pong 由 patches/xnu-ipados18/0001-pong-darwin24.patch 加入）
#
# 2. scripts/build-xnu-4k-baseline.sh: 给 vm_unix.o 单独打开 -DVM_UNSAFE_TYPES
#    installhdrs 是带该宏生成的（导出头里 mach_vm_*_ut 为 union），但内核编译没带，
#    vm_unix.c 因此有 12 处类型不匹配。pong/thor 官方构法（kits/PongPlatform24/
#    build-support/merged-scripts/build-xnu-ipados18.sh:666）正是只对 vm_unix.o 打开。
#
# 3. scripts/unixnu/kernel.py: 编译记录路径 DEVELOPMENT_ARM64_BCM2837 -> PONG
#    框架用这个文件的路径判断"是否已有一次编译记录"，进而决定要不要跑 bootstrap pass。
#    机器配置改成 PONG 后对象落在 DEVELOPMENT_ARM64_PONG，原来的判断永远为假，
#    bootstrap pass 的链接失败（XNU_BOOTSTRAP=1 本来就允许它停在链接）就会被当成致命错误。
#
# 用法： bash <device>/scripts/pin-baseline-machine-config.sh ../UniXNU
set -euo pipefail

UNIXNU_DIR=${1:-../UniXNU}
SCRIPT="$UNIXNU_DIR/scripts/build-xnu-4k-baseline.sh"
KERNEL_PY="$UNIXNU_DIR/scripts/unixnu/kernel.py"
[ -f "$SCRIPT" ] || { echo "missing $SCRIPT" >&2; exit 1; }
[ -f "$KERNEL_PY" ] || { echo "missing $KERNEL_PY" >&2; exit 1; }

tmp=$(mktemp)
python3 - "$SCRIPT" "$tmp" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
s = s.replace('MACHINE_CONFIGS=BCM2837', 'MACHINE_CONFIGS=PONG')
if 'vm_unix.o_CFLAGS_ADD=-DVM_UNSAFE_TYPES' not in s:
    if '-DXNU_OWNER_CACHE_CARRIER=' in s:
        s = re.sub(r'(vm_unix\.o_CFLAGS_ADD=)(?!-DVM_UNSAFE_TYPES)',
                   r'\1-DVM_UNSAFE_TYPES ', s, count=1)
    else:
        s = s.replace('EXTRA_MAKE_ARGS=()',
                      'EXTRA_MAKE_ARGS=()\nEXTRA_MAKE_ARGS+=("vm_unix.o_CFLAGS_ADD=-DVM_UNSAFE_TYPES")', 1)
open(dst, 'w').write(s)
print('baseline patched')
PY
mv "$tmp" "$SCRIPT"
chmod +x "$SCRIPT"

tmp=$(mktemp)
python3 - "$KERNEL_PY" "$tmp" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
s = s.replace('DEVELOPMENT_ARM64_BCM2837', 'DEVELOPMENT_ARM64_PONG')
open(dst, 'w').write(s)
print('kernel.py patched')
PY
mv "$tmp" "$KERNEL_PY"

echo "== verify =="
bc=$(grep -c 'MACHINE_CONFIGS=BCM2837' "$SCRIPT" || true)
bcpy=$(grep -c 'DEVELOPMENT_ARM64_BCM2837' "$KERNEL_PY" || true)
vu=$(grep -c 'vm_unix.o_CFLAGS_ADD=-DVM_UNSAFE_TYPES' "$SCRIPT" || true)
pongpy=$(grep -c 'DEVELOPMENT_ARM64_PONG' "$KERNEL_PY" || true)
echo "  baseline BCM2837 left: ${bc} (expect 0)"
echo "  kernel.py BCM2837 left: ${bcpy} (expect 0)"
echo "  kernel.py PONG refs: ${pongpy} (expect >=1)"
echo "  vm_unix macro: ${vu} (expect >=1)"
if [ "$bc" = "0" ] && [ "$bcpy" = "0" ] && [ "$vu" -ge 1 ] && [ "$pongpy" -ge 1 ]; then
  echo OK
else
  echo FAILED >&2
  exit 1
fi
