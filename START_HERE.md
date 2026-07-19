# Start here / 从这里开始

NuNuBar currently has two hardware-verified normal-user paths: Air65 V3 and
Air96 V2 ANSI on Apple Silicon macOS. Download the repository, open its folder
in Codex, and send the prompt below. Codex will return one explicit setup plan.

NuNuBar 当前只有两条实机验证的普通用户路线：Apple Silicon macOS 上的
Air65 V3 和 Air96 V2 ANSI。下载仓库、在 Codex 中打开文件夹并发送下面的提示词，
Codex 会直接返回一条明确配置计划。

## Prompt for Codex / 交给 Codex 的提示词

```text
请配置这个文件夹中的 NuNuBar，让我的 NuPhy 键盘同步 Codex 工作状态。

先阅读 AGENTS.md 和 START_HERE.md，再运行
python3 script/preflight.py --json。先向我汇报 setupPlan.path、required、
conditionalFirmwareRequirements、approvalGates 和 nextAction，不要立即修改电脑。
结合只读报告和我的实体确认，只能选择下面两条成功路线之一：
air65-v3-macos-wired 或 air96-v2-ansi-macos-v7。无法准确匹配时停止。

匹配 Air65 V3 后读取 docs/AIR65_V3_VERIFICATION.md；我要设置快捷键时再读取
docs/AIR65_V3_KEY_MAPPING.zh-CN.md。匹配 Air96 V2 ANSI 后读取
docs/AIR96_V2_SUCCESS.zh-CN.md。不要读取历史实验指南来决定普通用户路线。

安装或替换 App、写入 Codex Hooks、进入 DFU、刷写固件必须分开说明并分别获得
我的确认。写入 Hooks 前说明 ~/.codex/hooks.json 和 ~/.codex/config.toml 的
改动；写入后告诉我如何在 Codex 设置中审核四个 NuNuBar Hooks，并回到 App
重新检测。保留其他 Hooks 和配置，不得自动批准 Codex Hook 信任。Air65 V3
绝不刷固件；Air96 V2 必须先自检，能用就绝不重刷。最后运行 App 内灯光自检，并用真实
Codex 状态和 USB 拔插完成验收。如果我要配置 Air65 V3 按键或旋钮快捷键，
必须先说明该功能当前依赖官方 Karabiner-Elements；安装组件和写入
~/.config/karabiner/karabiner.json 都要分别取得我的确认。缺少实体观察时必须
如实标记为待验证。
```

`script/preflight.py` is read-only. Its `setupPlan` names the matched verified
path, requirements, approval gates, and next action. It does not install
software, edit Hooks, request permissions, enter DFU, or flash firmware.

`script/preflight.py` 是只读预检。它的 `setupPlan` 会直接给出匹配的成功路线、
所需材料、确认节点和下一步；不会安装软件、修改 Hooks、申请权限、进入 DFU
或刷写固件。

## What Codex should choose / Codex 应选择的路线

| Exact keyboard / 准确键盘 | Required path / 所需路线 | Verified result / 成功结果 |
| --- | --- | --- |
| Air65 V3 `19F5:102B` | Apple Silicon macOS, wired USB, NuNuBar, approved Codex Hooks; optional shortcuts additionally require Karabiner and NuPhyIO `F21/F22/F23` / Apple Silicon macOS、有线 USB、NuNuBar、已批准 Hooks；可选快捷键另需 Karabiner 与 NuPhyIO `F21/F22/F23` | Official firmware, no flash; Codex lights and right-knob task switching verified / 官方固件免刷，状态灯和右旋任务切换已验证 |
| Air96 V2 ANSI `19F5:3266` | Apple Silicon macOS, wired USB, NuNuBar, self-test first; only a failed self-test opens the backed-up v7 firmware flow / Apple Silicon macOS、有线 USB、NuNuBar、先自检；仅自检失败才进入有备份的 v7 固件流程 | v7 firmware, both side lights, custom states/effects, reconnect and real Codex transitions verified / v7 固件、双侧灯、自定义状态/灯效、重连和真实 Codex 切换已验证 |

Any other keyboard, Windows host, Intel Mac, Bluetooth-only connection, or
unknown physical layout is not one of these two normal-user success paths.
Codex must stop rather than substitute a similar model or testing artifact.

Air65 V3 status lighting does not require Karabiner. Its current macOS key and
knob mapping feature does require official Karabiner-Elements. NuNuBar may guide
installation and merge exact-device rules only after explicit confirmation.

其他键盘、Windows、Intel Mac、仅蓝牙连接或无法确认实体配列，都不属于这两条
普通用户成功路线。Codex 必须停止，不能拿相似型号或测试资产替代。

Air65 V3 状态灯不依赖 Karabiner；当前 macOS 按键和旋钮映射功能依赖官方
Karabiner-Elements。NuNuBar 可以提供安装引导并合并准确设备规则，但必须先获得
明确确认。

When an Air96 V2 user's firmware is unknown, the App sends an orange/green/red
self-test first. Visible changes skip every firmware and DFU step; no visible
change leads to USB troubleshooting before the model-locked firmware flow.

当 Air96 V2 用户不清楚当前固件时，App 会先发送橙、绿、红三色自检。灯光有
变化就跳过全部固件与 DFU 步骤；没有变化则先排查 USB，确认后才进入型号锁定
的固件流程。

## Expected result / 完成后的结果

- NuNuBar runs from the normal Applications/program location, preferably at login.
- Codex Hooks update only a local coarse state file; they do not read prompts or replies.
- The App owns keyboard communication and restores the current state after reconnect.
- Working, waiting, complete, and idle colors/effects can be adjusted in the App.
- On Air65 V3, optional key and knob mappings work through official
  Karabiner-Elements; lighting remains independent from it.
- Air96 V2 firmware is written only when its existing-firmware self-test fails;
  normal daily use never repeats the flash.

- NuNuBar 从正常应用目录运行，并可设置为登录时启动；
- Codex Hooks 只写入本地粗粒度状态，不读取提示词或回复；
- App 统一负责键盘通信，重连后自动恢复当前状态；
- 工作中、需要确认、完成、待机的颜色和灯效可在 App 中设置；
- Air65 V3 的可选按键和旋钮映射由官方 Karabiner-Elements 执行，灯光不依赖它；
- Air96 V2 只有现有固件自检失败时才刷写；日常使用不重复刷写。

## Public download requirement / 公开下载要求

General macOS users should receive a Developer ID signed and Apple-notarized
DMG from GitHub Releases. The Release workflow refuses to publish when signing
or notarization credentials are missing. Ad-hoc `UNNOTARIZED` builds are for
local development only and are not the normal user path.

面向普通 macOS 用户的 GitHub Release 必须提供 Developer ID 签名并经 Apple
公证的 DMG。缺少签名或公证凭据时，Release 工作流会拒绝发布。临时
`UNNOTARIZED` 构建仅用于本地开发，不属于普通用户安装路线。
