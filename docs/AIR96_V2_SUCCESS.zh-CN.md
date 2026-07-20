# Air96 V2 ANSI 已验证成功路线

这是 NuNuBar 当前三条实机成功路线之一，只适用于通过 USB 连接 Apple Silicon
Mac 的准确型号 NuPhy Air96 V2 ANSI。

## 用户需要准备

- Apple Silicon Mac，macOS 14 或更高版本；
- 根据键盘本体或包装确认型号和实体配列为 **Air96 V2 ANSI**；
- 支持数据传输的 USB 线，并把键盘切到有线模式；
- 安装在 `/Applications` 中的 NuNuBar；
- 手动检查并批准四个 Codex Hooks。

在测试现有固件前，不需要准备 DFU 材料。

## 最短决策流程

1. 运行 `python3 script/preflight.py --json`，必须得到
   `setupPlan.path = air96-v2-ansi-macos-v7`。
2. 安装并打开 NuNuBar，先运行橙色、绿色、红色灯光自检。
3. 三种颜色都可见：保留现有固件，跳过 DFU 和全部刷写，接入 Codex Hooks，
   再用真实任务验收。
4. 自检没有变化：先复查有线模式、数据线、准确型号和 App 检测。全部无误后，
   Codex 才能准备 v7 固件路线。

## 仅在自检失败时需要的 v7 固件材料

- 保存在仓库外的 VIA JSON 键位备份；
- 准确的 Air96 V2 ANSI 官方恢复固件及来源链接；
- 进入 DFU 前的单独确认；
- 唯一的 STM32 DFU 实体路径；
- 紧挨固件写入前的第二次独立确认。

已验证的内置固件：

- 文件：`NuphyBar-Air96-V2-ANSI-custom-effects-v7.bin`；
- 大小：`66088` 字节；
- SHA-256：`d3cfd9e76a38b70e823889197bdd92bc42e1fbfb96d938d02c4178720b0bb898`；
- 目标：`0483:DF11`、alternate `0`、地址 `0x08000000`。

通用 DFU ID 不能证明键盘型号。Codex 必须同时核对实体型号、ANSI 配列、应用
模式 `19F5:3266`、manifest、大小和 SHA-256，才能展示刷写命令。

## 成功标准

- 左右侧灯能区分待机、工作中、需要确认和完成；
- NuNuBar 中设置的颜色及常亮、呼吸、闪烁效果在实体键盘上可见；
- 真实 Codex 提示词能改变键盘状态；
- USB 拔插后无需重刷即可恢复；
- 正常输入和用户原有 VIA 键位保持正常；
- 用户知道 VIA 备份和官方恢复固件保存在哪里。

Air60 V2、Air75 V2 和 Halo75 V2 仅保留贡献者测试资产，不属于这条成功路线。
