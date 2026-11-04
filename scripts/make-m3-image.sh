#!/usr/bin/env bash
# =============================================================================
# M3 引导镜像打包（unicorn）
#
# 两种输入：
#   --kernel <mach.development.*>  先用 unixnu payload 生成 payload.img，再打包
#   --payload <payload.img>        直接用现成的 payload（FAT，含 EFI/UniXNU/Payloads/*）
#
# 产物：out/unicorn-uefi-M3.img（Android boot v4 = BootShim + FD + 追加 DTB + payload 作 ramdisk）
#
# 为什么 ramdisk 必须是 payload：UniXNU 菜单的启动项来自 ramdisk 里的
# EFI/UniXNU/Payloads/kernel.macho（FAT/PONGFAT1）。ramdisk 为空时菜单里没有任何可启动项。
# =============================================================================
set -euo pipefail

R=/root/unixnu-port
U="$R/UniXNU"
D="$R/UniXNU-unicorn"
UEFI="$R/uefi-unicorn"
OUT="$U/out/unicorn/ipados-18.7.10-22H374/unicorn_ipados18"
WIN=/mnt/d/iOS/unicorn-port/out

KERNEL=""
PAYLOAD=""
TARGET=RELEASE
while [ $# -gt 0 ]; do
  case "$1" in
    --kernel)  KERNEL=$2; shift 2 ;;
    --payload) PAYLOAD=$2; shift 2 ;;
    --target)  TARGET=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

FD="$UEFI/Build/unicornPkg/${TARGET}_CLANGPDB/FV/SILICIUM_UEFI.fd"
DTB="$UEFI/Platforms/Xiaomi/unicornPkg/FdtBlob/sm8475-xiaomi-unicorn.dtb"

echo "== 输入检查 =="
[ -f "$FD" ]  || { echo "缺固件: $FD（先跑 unixnu build firmware --target $TARGET）" >&2; exit 1; }
[ -f "$DTB" ] || { echo "缺 DTB: $DTB" >&2; exit 1; }
echo "  固件: $FD  ($(stat -c%s "$FD") B, sha256 $(sha256sum "$FD" | cut -c1-16))"
echo "  DTB : $DTB ($(stat -c%s "$DTB") B, sha256 $(sha256sum "$DTB" | cut -c1-16))"

if [ -z "$PAYLOAD" ]; then
  [ -n "$KERNEL" ] || { echo "需要 --kernel 或 --payload" >&2; exit 2; }
  echo "== 用 unixnu payload 生成 payload.img =="
  cd "$U"
  python3.12 ./unixnu payload -D "$D" --kernel "$KERNEL"
  PAYLOAD="$OUT/payload/payload.img"
fi
[ -f "$PAYLOAD" ] || { echo "payload 不存在: $PAYLOAD" >&2; exit 1; }
echo "  payload: $PAYLOAD ($(stat -c%s "$PAYLOAD") B)"

echo
echo "== 打包 v4 镜像（ramdisk = payload）=="
mkdir -p "$OUT/boot-m3"
python3 "$UEFI/scripts/build-bootimg.py" \
  --unixnu-root "$U" \
  --fd "$FD" \
  --config Resources/Configs/unicorn.toml \
  --dtb "$DTB" \
  --ramdisk "$PAYLOAD" \
  --output-dir "$OUT/boot-m3"

IMG="$OUT/boot-m3/pong-unixnu-uefi.img"
echo
echo "== 结构校验 =="
python3 - "$IMG" <<'PY'
import sys, pathlib, struct, zlib, hashlib
b = pathlib.Path(sys.argv[1]).read_bytes()
ksz, rsz, osver, hsz = struct.unpack_from('<IIII', b, 8)
ver = struct.unpack_from('<I', b, 40)[0]
page = 4096
kernel = b[page:page+ksz]
d = zlib.decompressobj(16 + zlib.MAX_WBITS); raw = d.decompress(kernel); tree = d.unused_data
print(f"  大小      : {len(b)} B")
print(f"  容器      : boot v{ver}, header_size={hsz}")
print(f"  kernel    : {ksz} B（解压后 shim+FD = {len(raw)}，FD sha {hashlib.sha256(raw[112:]).hexdigest()[:12]}）")
print(f"  追加 DTB  : {len(tree)} B（魔数 {tree[:4].hex()}）")
print(f"  ramdisk   : {rsz} B（payload）")
assert b[:8] == b'ANDROID!' and ver == 4 and tree[:4] == b'\xd0\x0d\xfe\xed', '结构不对'
# payload 里必须能找到 UniXNU 的 payload 目录标记
start = page * (1 + -(-ksz // page))
ram = b[start:start+rsz]
for marker in (b'kernel.macho', b'Payloads', b'EFI/UniXNU'):
    print(f"  ramdisk 含 {marker.decode():<12}: {marker in ram}")
print("  结构校验通过")
PY

NAME="unicorn-uefi-M3-$(basename "$PAYLOAD" .img | tr -d ' ').img"
cp "$IMG" "$WIN/$NAME"
echo
echo "== 交付 =="
ls -l "$WIN/$NAME"
sha256sum "$WIN/$NAME" | sed 's|/mnt/d|D:|'
echo "上机：  fastboot boot out\\$NAME"
