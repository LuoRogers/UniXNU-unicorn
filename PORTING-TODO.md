# UniXNU-unicorn 未完成项

由 UniXNU-thor（小米 12S Ultra / SM8475 / iPadOS 18.7.10）复制改名而来。

## 必须用本机事实替换（M0 采集后关闭）
- [ ] `dts/unicorn.dts`：`reserved-memory` 全表、`memory` 容量、`&ufs` 参数、`&pcie0` 参数、按键 PON PPID、触摸节点
- [ ] `board.toml [userdata]`：`first_lba` / `last_lba`（继承的是 Pong 的 0x413248 / 0x75A40EA）
- [ ] `board.toml [ipsw]`：chip_id / board_id 若与 J171AP 不同需改（iPad 7 代 0x8010 / 0x1c 一般可留）
- [ ] `configs/unicorn_ipados18_defconfig`：按本机 GPU/存储/显示做裁剪
- [ ] `proprietary-files.txt`：unicorn 自己的固件文件清单

## 代码/脚本改名（不影响构建，逐步做）
- [ ] `scripts/*.py` 里 `pong_*` 前缀的 boot-arg、探针、路径 → `unicorn_*`
- [ ] `drivers/` 的 submodule 目前仍指向 pong-* 仓库（同 SoC，可先用）
- [ ] `kits/PongPlatform24` 名称与内部 `PONG` 编链开关（`MACHINE_CONFIGS=PONG`）
- [ ] `patches/xnu-ipados18/*` 里的 `pong-` 命名与板级分支

## 移植记录
- [ ] `porting.toml` 按 unicorn 重写（参考 mondrian 的 14 子系统结构）
