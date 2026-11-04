# 证据：M1/M2 —— UniXNU 菜单在本机屏幕上出现并可操作

* 设备：Xiaomi 12S Pro（unicorn，SM8475），BL 已解锁
* 方式：`fastboot boot <镜像>`（只进 RAM，全程未写任何分区）
* 日期：2026-11-04 / 11-05

## 观察到的现象

| 镜像 | 屏幕 | 主机侧 |
| --- | --- | --- |
| `unicorn-uefi-M1f-goldfd.img`（gold FD + 本机 DTB + 1 MiB 占位 ramdisk） | **出现 UniXNU 菜单**，音量键可移动、电源键可确认 | `fastboot boot` 后 3–42 s 内**无任何 USB 设备**（UEFI 阶段正常），90 s 内未自动重启 |
| `unicorn-uefi-M1e-v4ramdisk.img`（我们自己构建的 RELEASE 固件，FD sha256 `428c9fca…`） | 菜单出现；倒计时结束后显示**警示三角形**并关机 | 同上，固件持续运行 |

## 判读要点（踩过的坑）

1. **不要用 `adb devices` 判断固件是否存活**：adb server 会先返回幽灵设备，
   导致误判成"6 秒就回安卓、固件崩了"。正确做法是采样 **USB VID/PID**：
   UEFI 阶段完全没有 USB；回到安卓才出现 `VID_18D1&PID_4EE7`。
2. **菜单倒计时结束后出现警示三角形并关机是预期行为**：镜像的 ramdisk 只有 1 MiB 全零占位，
   没有任何可启动项，配置里的 `shutdown` 条目被执行（`UniXNUActionShutdown` →
   `gRT->ResetSystem (EfiResetShutdown, …)`）。
3. 手机停在 UEFI/菜单里时，adb 与 fastboot 都不可达；长按电源 10 秒即可重启。

## 结论

* M1（UEFI 上屏 + 菜单渲染）达成；
* M2（菜单可读 + 实体键可用）达成；
* 显示与输入的"最低通路"已被证明可用，后续风险集中在 Apple 侧驱动。
