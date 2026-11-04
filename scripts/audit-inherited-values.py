#!/usr/bin/env python3
"""审计「继承自兄弟设备的数值」是否还没被本机事实替换。

本移植从 UniXNU-thor（小米 12S Ultra）与 uefi-mondrian（红米 K60）改名复制而来，
里面每一条地址/几何/PPID 在验证前都是**邻居设备的值**，直接上机会黑屏或崩溃，
而且 XNU/UEFI 阶段几乎没有日志通道，试错成本极高。

用法：
    python3 scripts/audit-inherited-values.py                 # 只报告
    python3 scripts/audit-inherited-values.py --strict        # 有未确认项则退出码 1
    python3 scripts/audit-inherited-values.py --facts verified-facts.json

`verified-facts.json` 里出现的键视为「已用本机实测替换」，见 verified-facts.example.json。
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent

# (相对路径, 正则, 键名, 说明)
CHECKS = [
    ("board.toml", r"first_lba\s*=\s*(0x[0-9a-fA-F]+)", "userdata.first_lba",
     "userdata 起始 LBA（继承 Pong 的 0x413248）"),
    ("board.toml", r"last_lba\s*=\s*(0x[0-9a-fA-F]+)", "userdata.last_lba",
     "userdata 结束 LBA（继承 Pong 的 0x75A40EA）"),
    ("board.toml", r"owned_memory_size\s*=\s*\"(0x[0-9a-fA-F]+)\"", "adt.owned_memory_size",
     "DarwinBoot 分配窗口（继承 4 GiB）"),
    ("dts/unicorn.dts", r"memory@[0-9a-f]+ \{ device_type = \"memory\"; reg = <0x0 0x80000000 0x([0-9a-f]+) 0x([0-9a-f]+)>",
     "dts.dram_size", "DRAM 容量（继承 thor 的 12 GiB）"),
    ("dts/unicorn.dts", r"pong,ufs-spi = <(\d+)>", "dts.ufs_spi",
     "UFS SPI 号（继承 Pong 的 265）"),
    ("dts/unicorn.dts", r"pong,smmu-stream-id = <(0x[0-9a-f]+)>", "dts.ufs_smmu_sid",
     "UFS SMMU StreamID（继承 Pong 的 0xe0）"),
    ("dts/unicorn.dts", r"pon-ppid = <(0x[0-9a-f]+)>", "dts.pon_ppid",
     "PON 按键 PPID（本机 pm8998-pon pwrkey = 0x13）"),
    ("dts/unicorn.dts", r"irq-gpio-num = <([0-9]+)>", "dts.touch_pins",
     "触摸 IRQ GPIO（本机 fts = 21）"),
    ("dts/unicorn.dts", r'compatible = "(unicorn,focaltech-fts)"', "dts.touch_compatible",
     "触摸 IC 兼容串（本机 fts = FocalTech，SPI 0x990000）"),
]

# 固件仓（可选，同目录下 ../uefi-unicorn）
UEFI_CHECKS = [
    ("Platforms/Xiaomi/unicornPkg/unicorn.dsc",
     r"PcdCPUCoresStackBase\|(0x[0-9a-fA-F]+)", "uefi.cpu_stack_base",
     "UEFI CPU 栈基址（继承 K60 的 0xA760D000）"),
    ("Resources/Configs/unicorn.toml",
     r"^\s*base\s*=\s*(0x[0-9a-fA-F]+)", "uefi.fd_base",
     "UEFI FD 基址（继承 K60 的 0xA7400000，为避开其 ramoops）"),
    ("Resources/Configs/unicorn.toml",
     r"^\s*size\s*=\s*(0x[0-9a-fA-F]+)", "uefi.fd_size", "UEFI FD 大小"),
    ("Resources/Configs/unicorn.toml",
     r"header_version\s*=\s*(\d+)", "uefi.boot_header_version",
     "boot image header 版本（继承 K60 的 v4）"),
]


def scan(root: Path, checks, facts: dict, out: list) -> None:
    for rel, pattern, key, note in checks:
        p = root / rel
        if not p.exists():
            out.append(("MISS", key, rel, "-", note))
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        m = re.search(pattern, text, re.MULTILINE)
        if not m:
            out.append(("--", key, rel, "(未找到该字段)", note))
            continue
        value = " ".join(g for g in m.groups() if g) if m.groups() else m.group(0).strip()
        status = "OK" if key in facts else "INHERIT"
        out.append((status, key, rel, value, note))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--facts", default="verified-facts.json")
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()

    facts = {}
    fp = HERE / args.facts
    if fp.exists():
        facts = json.loads(fp.read_text(encoding="utf-8")).get("verified", {})
        print(f"[facts] {fp} 里已确认 {len(facts)} 项\n")
    else:
        print(f"[facts] 没有 {args.facts}，所有继承值都会被标为未确认\n")

    rows: list = []
    scan(HERE, CHECKS, facts, rows)
    if (HERE.parent / "uefi-unicorn").exists():
        scan(HERE.parent / "uefi-unicorn", UEFI_CHECKS, facts, rows)

    w = max(len(r[1]) for r in rows) + 2
    pending = 0
    print(f"{'状态':<8}{'键'.ljust(w)}{'值':<22}说明")
    print("-" * 110)
    for status, key, rel, value, note in rows:
        if status == "INHERIT":
            pending += 1
        print(f"{status:<8}{key.ljust(w)}{str(value):<22}{note}")
    print("-" * 110)
    print(f"共 {len(rows)} 项，未确认 {pending} 项")
    if pending:
        print("\n未确认项必须以本机采集结果替换后再上机（M1 黑屏/崩溃的主要来源）。")
        print("替换后在 verified-facts.json 里登记键名与实测值，本脚本即转 OK。")
    return 1 if (args.strict and pending) else 0


if __name__ == "__main__":
    sys.exit(main())
