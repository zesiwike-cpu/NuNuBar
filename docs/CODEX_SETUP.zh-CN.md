# 使用 Codex 安全配置 NuNuBar

NuNuBar 可以把本地 Codex 的工作状态显示在兼容的 NuPhy 键盘灯光上。
新用户只需把本仓库地址交给 Codex，即可让它准备正确的 App；但键盘
识别和所有可能破坏现有状态的操作，必须依然由用户本人确认。

## 交给 Codex 的提示词

```text
请从本任务附带的仓库链接安全配置 NuNuBar。
严格遵守 AGENTS.md、START_HERE.md、docs/CODEX_SETUP.zh-CN.md 和
docs/VERIFIED_PATHS.zh-CN.md。先运行 python3 script/preflight.py --json，
汇报 setupPlan.path、required、conditionalFirmwareRequirements、approvalGates
和 nextAction，再结合我的实体确认精确型号和 ANSI 配列。setupPlan.path 只能是
air65-v3-macos-wired、air75-v3-macos-wired-1.0.14.6 或
air96-v2-ansi-macos-v7；否则必须停下来如实说明。
在你说明当前这一个具体操作，
并为它单独获得我的确认之前，不得进入 DFU、刷写固件、替换已有 App/配置，
也不得写入 Codex Hooks。保留其他配置，检测到多个 DFU 设备时立即停止，
不要自行选择。最后逐项完成公开的成功验收清单，缺少必需观察时不得宣称成功。
```

Codex 应先克隆或检查仓库，汇报已识别的信息，遇到缺少的事实或必需
的确认时停下来询问。把仓库 URL 交给 Codex，不等于授权它修改电脑
或键盘固件。

只读预检会同时运行仓库完整性校验，并报告 App/Hooks 是否存在、候选键盘和
控制接口是否就绪。V2 的 VID/PID 与 Raw HID 就绪不代表已经安装兼容固件；
应先运行 App 灯光自检，已有响应时禁止重复刷写。

支持决策矩阵和最终验收项目见[已验证的成功路径](VERIFIED_PATHS.zh-CN.md)。

## 配置前准备

三条路线共同需要：

- 键盘本体或包装上标注的精确型号；
- 确认实体键盘是 ANSI 配列；
- 一条稳定的 USB 数据线，并尽量直接连接电脑。

Air65 V3 不需要 VIA 备份、恢复镜像或任何固件材料。Air75 V3 使用官方
`1.0.14.6` 或更高固件；旧版本必须先导出 NuPhyIO 配置，并单独确认官方升级。
Air96 V2 也必须先测试
现有固件；只有灯光自检失败后，才准备 VIA JSON 备份和准确官方恢复固件，且两者
都保存在仓库之外，不提交到 Git 或公开 Issue。

Air65/Air75 V3 状态灯不依赖 Karabiner。可选的型号独立按键和旋钮映射编辑器
使用官方 Karabiner-Elements 执行准确设备限定规则。请按
[`AIR65_V3_KEY_MAPPING.zh-CN.md`](AIR65_V3_KEY_MAPPING.zh-CN.md) 或
[`AIR75_V3_KEY_MAPPING.zh-CN.md`](AIR75_V3_KEY_MAPPING.zh-CN.md) 执行；安装
Karabiner 和写入 `~/.config/karabiner/karabiner.json` 都必须由用户在明确提示后
决定。黄色键 Fn/地球键路线另见
[`AIR65_V3_FN_SHORTCUT.zh-CN.md`](AIR65_V3_FN_SHORTCUT.zh-CN.md)。

## 支持型号

| 型号 | USB VID:PID | 当前固件状态 | 灯区 |
| --- | --- | --- | --- |
| Air65 V3 | `19F5:102B` | 官方固件直连；自动配置读取、默认橙/绿/红和真实 Codex 切换已验证 | 侧灯 |
| Air75 V3 | `19F5:1028` | 官方 `1.0.14.6` 或更高；型号独立的官方有线协议已验证 | 侧灯 |
| Air96 V2 ANSI | `19F5:3266` | v7 路线已实机验证；必须先自检 | 左右侧灯条 |

这三款是仅有的普通用户路线。Air60 V2、Air75 V2、Halo75 V2、Windows 和其他
硬件只保留贡献者资产，普通 Codex 配置不得选择。

## macOS

当前 macOS App 面向 Apple Silicon，需要 macOS 14 或更高版本。

Codex 应优先使用指定 GitHub Release 中附带的 DMG。安装本地 DMG：

```bash
./script/setup-macos.sh \
  --dmg /path/to/NuNuBar-<version>-macOS-arm64.dmg \
  --allow-unnotarized \
  --sha256 <可选的预期-sha256>
```

下载指定 Release 资产：

```bash
./script/setup-macos.sh \
  --release OWNER/REPOSITORY \
  --tag v<version> \
  --asset NuNuBar-<version>-macOS-arm64.dmg \
  --sha256 <可选的预期-sha256>
```

请把 `OWNER/REPOSITORY` 替换成浏览器地址中显示的实际仓库路径。

也可以直接使用 GitHub Release 中 DMG 的下载链接：

```bash
./script/setup-macos.sh --release-url <github-release-dmg-url>
```

脚本会校验可选 SHA-256、验证 App 签名，然后安装 `NuNuBar.app`。正式
GitHub Release 资产的 DMG 和 App 都必须通过 Gatekeeper 评估，安装全程保留
quarantine 属性。如果目标位置已有 App，脚本会在替换前询问。它不会进入
DFU、刷固件、修改 Codex Hooks，也不会自动启动 App。

本地 DMG 或文件名包含 `UNNOTARIZED` 的资产属于开发构建。安装时必须显式
加上 `--allow-unnotarized`，并在互动提示中再输入一次 `UNNOTARIZED`。Codex
必须说明它可能被 macOS 阻止，即使某次本地评估恰好通过，也不得把它描述成
可直接通过 Gatekeeper 的正式版。

安装完成后，手动启动 NuNuBar，并用 USB 连接键盘。V2 型号的自定义 RGB 和灯效
依赖 USB Raw HID 以及匹配的 NuNuBar 固件；Air65/Air75 V3 直接使用各自的官方
有线控制接口。V3 可以通过蓝牙打字，但当前版本的 Codex 侧灯必须使用 USB 有线模式。
连接 Codex 是另一项配置变更：
NuNuBar 可以提议局部 Hooks 配置，但写入前 Codex 必须展示受影响的路径/条目，
保留其他内容，并单独获得确认。用户仍需在 Codex 设置中手动同意 Hooks。

## Codex Hooks 操作步骤

1. 先启动一次 Codex，让 `~/.codex` 配置目录存在。
2. 在 NuNuBar 的“Agent”页面点击“接入”，或在新键盘向导中点击“接入 Codex”。
3. NuNuBar 会先备份再合并 `~/.codex/hooks.json`，并在
   `~/.codex/config.toml` 的 `[features]` 中启用 `hooks = true`。其他字段、
   Hooks 和通知设置会保留。
4. 打开 Codex 设置中的 Hooks 待审核项，逐项确认命令来自当前安装的
   `NuNuBar.app/Contents/Helpers/agent-light`，然后批准以下四个事件：
   `UserPromptSubmit`、`PermissionRequest`、`PostToolUse`、`Stop`。
5. 回到 NuNuBar 点击“重新检测”。只有页面显示“已接入”，才算 Hooks 配置完成。
6. 新建一个 Codex 任务，实际观察工作中、需要确认和完成灯光；演示灯变化不能
   代替真实 Hook 验收。

Hooks 只向本机助手发送 Agent 名称、粗粒度状态、会话 ID 和时间，不读取提示词
或回复内容。不要在 Codex 对话中输入 `/hooks`；这里需要操作的是 Codex 的设置
与待审核 Hooks。NuNuBar 不会也不能代替用户批准 Hook 信任。

## 其他平台

目前没有经过实机验证的 Windows 或 Intel Mac 普通用户路线。必须停止并说明
限制。仓库可以保留贡献者代码，但不得据此宣称配置成功。

## 固件流程

只有准确的 Air96 V2 ANSI 在现有固件自检失败后才需考虑内置固件。Air65/Air75
V3 已有官方接口，禁止进入 V2 DFU 或刷写 V2 固件。Air75 V3 低于 `1.0.14.6`
时只使用 [`AIR75_V3_VERIFICATION.zh-CN.md`](AIR75_V3_VERIFICATION.zh-CN.md)
记录的、经单独确认的 NuPhyIO 官方升级。Air96 先阅读
[`AIR96_V2_SUCCESS.zh-CN.md`](AIR96_V2_SUCCESS.zh-CN.md)，再按以下顺序执行：

1. 检测应用模式的 USB VID/PID，并与键盘上的型号交叉核对。
2. 确认 ANSI、VIA 备份、官方恢复固件和该型号的 catalog 条目。
3. 校验内置固件的字节大小和 SHA-256。
4. 说明 DFU 的影响，单独获得确认后，才请用户手动进入 DFU。
5. 只接受唯一的 STM32 DFU 实体路径，且 Option Bytes 与 Internal Flash
   必须在同一路径上。
6. 展示精确固件文件、验证状态、哈希、DFU 路径、alt `0` 和 `0x08000000`。
7. 紧挨写入命令之前，再次获得一个新的刷写确认。
8. 刷写后用 USB 重连，验证输入、所有状态/灯效、休眠唤醒及官方恢复路线。

通用 DFU ID `0483:DF11` 无法用来识别键盘型号。检测结果不唯一、型号/配列
不符、哈希失败或缺少恢复材料时，必须停止，不得刷写。

## 默认状态灯

默认设置为：待机熄灭、工作中橙色呼吸、等待确认/错误红色闪烁、完成绿色常亮。
Air96 V2 在固件中渲染灯效；Air65/Air75 V3 使用官方控制接口，其中“闪烁”由
App 生成。三条已验证路线都使用 USB。字节级协议见 `docs/NBAR_PROTOCOL.md`。
