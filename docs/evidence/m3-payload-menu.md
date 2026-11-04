# 证据：M3 装载机制 —— 菜单按 payload 清单渲染出 4 个启动项

* 设备：Xiaomi 12S Pro（unicorn，SM8475）
* 方式：`fastboot boot out/unicorn-uefi-M3-payload.img`（102 MB，只进 RAM）
* 日期：2026-11-05

## 该镜像的组成

| 部分 | 内容 |
| --- | --- |
| 容器 | Android boot header **v4**，`header_size=1584`，无 ramdisk 压缩 |
| kernel 段 | gzip(BootShim + `SILICIUM_UEFI.fd` 3,145,728 B) + 追加本机 DTB 895,141 B（魔数 `d00dfeed`） |
| **ramdisk** | `payload.img` 100,663,296 B —— FAT，卷标 `UNIXNU`，内含 `/EFI/UniXNU/UniXNU.toml` 与 `/EFI/UniXNU/Payloads/kernel.macho`(+`.adt`/`.trustcache`) |

`payload.img` 里的清单（用 `mtools` 直接读出）：

```toml
version = 1
[boot] timeout = 5   default = "xnu"
[[entry]] id="xnu"      title="UniXNU"     type="xnu"    path="Payloads/kernel.macho"
[[entry]] id="reset"    title="Restart"    type="action" action="reset"
[[entry]] id="shutdown" title="Power off"  type="action" action="shutdown"
[[entry]] id="tools"    title="Tools"      type="action" action="tools"
```

## 观察到的现象

* 屏幕上菜单**显示 4 个条目**（UniXNU / Restart / Power off / Tools），与清单完全一致；
* 超时/选中后没有出现绿条或 panic，而是**警示三角形 + 关机**。

## 结论

1. 固件读取 ramdisk、解析 `UniXNU.toml`、渲染菜单这条链**完全正常**（否则不会出现 4 项）；
2. 该 payload 里的内核是 **Darwin 22.6.0**（iOS 16.6.1 路线），与本项目 darwin24 的
   DarwinBoot（boot_args ABI 0x480/1024）**版本契约不匹配**，装载器拒绝后回落到 `shutdown` 条目；
3. 因此 M3 只差一份 **darwin24 的 `kernel.macho`**：菜单、payload 格式、容器、DTB、显示、按键均已验证可用。
