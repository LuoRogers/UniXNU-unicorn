# 硬件事实（本机实测，M0 采集结果）

来源：`D:\iOS\unicorn-port\data\unicorn-20261104-210322\`
采集方式：adb + root 只读 dump（`scripts/collect-device.sh`），**未写入任何分区**。

> 凡是写在 `dts/unicorn.dts` / `board.toml` / `Resources/Configs/unicorn.toml` 里的板级数值，
> 都必须能在这份表里找到出处。表里没有的，就是还没测。

## 1. 设备身份

| 项 | 实测值 | 出处 |
| --- | --- | --- |
| 代号 | `unicorn` | `getprop ro.product.device` |
| 型号 | `2206122SC` | `ro.product.model` |
| SoC | SM8475（`ro.board.platform=taro`） | `getprop` |
| 硬件 SKU | `unicorn` | `ro.boot.hardware.sku` |
| 系统 | MIUI V140 / `V14.0.11.0.TLECNXM`（Android 13） | `ro.build.version.incremental` |
| 槽位 | `_a` | `ro.boot.slot_suffix` |
| BL 状态 | 已解锁（`verifiedbootstate=orange`，`flash.locked=0`） | `getprop` |
| DT model | `Unicorn based on Qualcomm Technologies, Inc SM8475` | live DT |
| GPU | **Adreno 730 v3**（`qcom,gpu-model = "Adreno730v3"`） | live DT |

## 2. 内存

| 项 | 实测值 | 出处 |
| --- | --- | --- |
| MemTotal | 11,444,364 kB（≈ 12 GiB 物理） | `/proc/meminfo` |
| DT `ddr_size` | `0x0c`（12 GB 档） | live DT `memory` 节点 |
| DRAM 基址 | `0x80000000` | live DT / iomem |
| ramoops | `0xa7000000` + `0x400000`（到 `0xa73fffff`） | live DT `reserved-memory` |
| 保留区个数 | 38（全部已抄进 `dts/unicorn.dts`） | live DT |
| **UEFI FD 落点** | `0xA7400000` 长度 `0x300000`（脚本校验：不在任何保留区内） | live DT + `/proc/iomem` |
| **UEFI CPU 栈** | `0xA7700000`（FD 区之后，iomem 显示为 System RAM 且无保留项） | `/proc/iomem` |

## 3. 显示

| 项 | 实测值 | 出处 |
| --- | --- | --- |
| 面板节点 | `qcom,mdss_dsi_l2s_38_0c_0a_dsc_cmd` | `bootargs msm_drm.dsi_display0=...` |
| 面板名 | “xiaomi 38 0c 0a cmd mode dsc dsi panel” | live DT |
| 分辨率 | **1440 × 3200**（`panel-width=0x5a0`、`panel-height=0xc80`） | live DT + `dumpsys display` |
| 刷新率 | 120 / 90 / 60 / 40 / 30 / 24 Hz（LTPO 多档） | `dumpsys display` |
| 传输 | DSI cmd mode + DSC（10bpc，slice 720×50，`slice-per-pkt=2`） | live DT |
| DCS 初始化序列 | 已完整导出 → `panel-l2s-dcs.txt` | live DT `qcom,mdss-dsi-on-command` |
| 固件用 DTB | `uefi-unicorn/.../FdtBlob/sm8475-xiaomi-unicorn.dtb`（= 本机 live DT 895 KB） | 采集 |

## 4. 触摸（FocalTech FTS）

| 项 | 实测值 | 出处 |
| --- | --- | --- |
| 驱动/兼容 | `fts@0`，`compatible = "st,spi"`；固件名 `st_fts_l2s.ftb` | live DT |
| 总线 | SPI `990000.spi`（qup），`spi-max-frequency = 12 MHz` | live DT + `input-devices.txt` |
| 中断 | GPIO 21（`fts,irq-gpio = <&tlmm 0x15 flags 0x2008>`） | live DT |
| 复位 | GPIO 20 | live DT |
| 坐标范围 | `x-max = 14400`、`y-max = 32000`（面板 1440×3200 的 10 倍定点） | live DT |
| 供电 | `avdd` / `vdd`（PMIC 稳压器） | live DT |
| 设备节点 | `/dev/input/event7`（name `fts`） | `input-devices.txt` |

## 5. 按键 / PMIC

| 项 | 实测值 | 出处 |
| --- | --- | --- |
| PMIC PON | `pm8998-pon@1300`（PMK8350，spmi `c42d000`） | live DT |
| 电源键 | `pwrkey`，PON **PPID `0x13`**（`interrupts = <0 0x13 7 3>`） | live DT |
| 音量上 | **TLMM GPIO 6**（`gpio_keys/vol_up`，`linux,code=0x73`） | live DT |
| resin | 存在（`pmic_resin`） | `input-devices.txt` |
| 马达 | `awinic_haptic`（i2c-5 0x5a） | `input-devices.txt` |

> 与 pong 的差异：pong 的音量键是 PON PPID `0x18d`；unicorn 是 **GPIO 6**。这是本机实测的关键差异。

## 6. 存储（UFS）

| 项 | 实测值 | 出处 |
| --- | --- | --- |
| 控制器 | `ufshc@1d84000`（reg 三窗口：`0x1d84000/0x3000`、`0x1d88000/0x8000`、`0x1d90000/0x9000`） | live DT + iomem |
| 中断 SPI | `0x109` = **265** | live DT |
| SMMU StreamID | **`0xe0`**（`iommus = <0x5b 0xe0 0>`） | live DT |
| 通道 | `lanes-per-direction = 2` | live DT |
| 复位 GPIO | 210（`reset-gpios = <&tlmm 0xd2 1>`） | live DT |
| ICE | 有（`ufs_ice` / `ufs_ice_hwkm` 窗口） | live DT |
| 分区表 | `sda` 为主盘；`userdata` 起始 512B 扇区 24104960、大小 469749720 扇区（4K LBA：3013120 / 58718715，末 LBA 61731834） | `/sys/block/sda/sda36/{start,size}` |
| 关键分区 | `boot_a=sde14`、`dtbo_a=sde18`、`vendor_boot_a=sde25`、`super=sda28`、`userdata=sda36`、`persist=sda21` | `/dev/block/by-name` |

## 7. Wi-Fi / 蓝牙

| 项 | 实测值 | 出处 |
| --- | --- | --- |
| 芯片 | **QCA6490**（`qcom,cnss-qca6490@b0000000`） | live DT + `dmesg` |
| 总线 | PCIe RC0 `qcom,pcie@1c00000`（`1c00000.qcom,pcie`），link 已训练 | `dmesg` |
| wlan-en | TLMM GPIO 80（`wlan-en-gpio = <&tlmm 0x50>`） | live DT |
| perst / wake / clkreq | GPIO 94 / 96 / 95 | live DT |
| 固件 | `qca6490/amss20.bin`、`bd_l2sgf.elf`、`regdb_xiaomi.bin` | `dmesg` |
| 蓝牙 | `bt_qca6490`（`qcom,qca6490`） | live DT |

## 8. USB / 音频 / 其它

| 项 | 实测值 | 出处 |
| --- | --- | --- |
| USB | `a600000.dwc3` + eUSB2 repeater（i2c 0x4f）+ `fsa4480`（i2c 0x42） | `dmesg` |
| 音频 | `lpass-cdc`（WCD938x 族），`waipio-mtp-snd-card` | `dmesg` + DT |
| 串口 | `qcom,qup_uart@99c000`（`console=ttyMSM0`，`msm_geni_serial.con_enabled=0`） | live DT bootargs |
| 指纹 | `goodix`（`fingerprint_goodix`，GPIO） | live DT |

## 9. 仍然缺的（下一步要测）

- `fastboot getvar all`：分区尺寸、`current-slot`、header 版本交叉验证、`anti`/rollback。
- 面板 DSI 通道数 / PHY 版本（从 `dsi_phy` 节点补齐，用于固件 DSI 初始化）。
- 电量/充电曲线（`PongPower` 类驱动需要）。
- 用户态阶段的 APFS 卷布局（macOS 侧生成）。
