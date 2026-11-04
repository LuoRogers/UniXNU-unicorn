# UniXNU-unicorn

小米 12S Pro（**unicorn**，型号 2206122SC，高通 **SM8475** / taro）的 UniXNU 设备仓，格式 2（`schema_version = 2`）。

- 目标系统：**iPadOS 18.7.10 / 22H374 / darwin24**（与 `UniXNU-thor`、`UniXNU-zizhan` 同路线）
- 模板来源：`SFZ97/UniXNU-thor`（小米 12S Ultra，同 SoC）→ 改名 + 全量替换板级数据
- 配套固件仓：`../uefi-unicorn`（由 `Emilelu/uefi-mondrian` 改名 + `unicornPkg`）

## 当前状态（诚实版）

| 层 | 状态 |
| --- | --- |
| 格式 2 配置解析 | ✅ `unixnu status` 四层 profile 全解析 |
| 源码获取 | ✅ `unixnu fetch` 全部 pin 到位（xnu `43a90889`、libplatform、libdispatch、libpthread、corecrypto、IOStorageFamily、AvailabilityVersions、edk2、sm8475 种子） |
| 硬件 DTS | ✅ 由本机 live DT 生成，`dtc` 编译通过（6331 B） |
| 板级数值 | ✅ 13/13 项「本机实测」登记完成（`verified-facts.json`，`scripts/audit-inherited-values.py` 全 OK） |
| 内核构建 | ⛔ 未通：设备链的 macOS 前置（`volume-layout.json`）绕不过；Linux 侧应改走 `kits/PongPlatform24/build-support/merged-scripts/build-xnu-ipados18.sh`（`MACHINE_CONFIGS=PONG`），进行中 |
| UEFI 固件 | ⛔ 未构建：`uefi-unicorn` 的 EDK2/Mu 子模块拉取中 |
| 上机 | ⛔ 未开始（M1 未做） |

## 板级事实（全部本机实测，见 `docs/HARDWARE-FACTS.md`）

| 子系统 | unicorn 实测 | 与 pong 的差异 |
| --- | --- | --- |
| SoC / DRAM | SM8475，12 GiB @ `0x80000000` | 同 |
| 面板 | `qcom,mdss_dsi_l2s_38_0c_0a_dsc_cmd`，**1440×3200**，DSC 10bpc，120 Hz LTPO | 不同（pong 1080×2412） |
| 触摸 | **FocalTech FTS**，SPI `0x990000`，IRQ GPIO 21 / RST GPIO 20，12 MHz | 不同（pong 是 Goodix Berlin-D） |
| 按键 | 电源 = PON PPID `0x13`；**音量上 = TLMM GPIO 6** | **不同**（pong 音量走 PON `0x18d`） |
| UFS | `1d84000.ufshc`，SPI 265，SMMU SID `0xe0`，2 lane | 同 |
| Wi-Fi | **QCA6490**，PCIe RC0 `0x1c00000`，wlan-en GPIO 80 | 同族 |
| GPU | Adreno 730 v3 | 同 |
| userdata | 4K LBA `3013120` … `61731834`（224 GiB） | 不同 |

## 构建（Linux/WSL）

```sh
# 1. 一次性引导：pin 框架仓 → 重建确定性 SoC 种子 → 装 22H374 profile → defconfig/fetch/status
bash scripts/bootstrap-unicorn.sh --unixnu ../UniXNU --soc ../soc-seed

# 2. 硬件 DTS → DTB（验证板级描述）
python3.12 scripts/build-pong-format2.py --unixnu ../UniXNU --out ../build \
        --jobs 4 --defconfig unicorn_ipados18_defconfig

# 3. 审计：任何还没用本机实测替换的继承值都会被点名
python3 scripts/audit-inherited-values.py --strict
```

需要 macOS/Xcode 的步骤（APFS userdata、`volume-layout.json`）走 GitHub Actions 的
`macos-15-intel` runner，参考 `UniXNU-thor` 的 `package` workflow。

## 数据安全红线

- 上机一律 `fastboot boot`（RAM 临时引导），**不 flash 任何分区**。
- **禁止** `fastboot flash persist` / `flash all`（TEE 密钥不可逆损坏）。
- UniXNU 的 OS / SystemOS / Data 窗口放在 `userdata` **尾部 64 GiB**；
  安装前必须先收缩安卓 data 文件系统（`board.toml [userdata]` 里的 TODO(resize)）。

## 许可

设备级代码 BSD-2-Clause-Patent；导入组件保留各自 SPDX 与许可证，见 `THIRD_PARTY_NOTICES.md`。
