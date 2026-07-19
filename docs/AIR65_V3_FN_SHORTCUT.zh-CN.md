# Air65 V3 黄色键 Fn 快捷功能

这是一条可选的 macOS 路线：把准确型号 NuPhy Air65 V3 `19F5:102B` 上的实体
黄色 `PGDN` 键转换为 Apple 原生 `Fn/地球键`。它与 Codex 状态灯相互独立，
不会刷固件、修改 Hooks，也不会改变 NuNuBar 灯光协议。

## 已验证结果

完整链路已于 2026-07-18 在以下环境完成实机验证：

- Apple Silicon、macOS 15.1；
- Air65 V3 有线 USB，`19F5:102B`；
- 官方 NuPhyIO 2.0，Mac 模式、M1 配置；
- 官方 Karabiner-Elements 16.1.0，已通过 Apple 公证；
- 在 NuPhyIO 中把实体黄色 `PGDN` 位置保存为 `F24`；
- Karabiner 使用设备限定规则，把 `F24` 转成
  `apple_vendor_top_case_key_code: keyboard_fn`。

Karabiner-EventViewer 已记录来自 DriverKit 虚拟键盘的 `keyboard_fn` 按下和松开，
所以通过的是完整实体按键链路，不只是 JSON 语法检查。

## 为什么使用 F24

`F24` 只是中间传递信号。它很少与 macOS 日常快捷键冲突，Karabiner 收到后再
输出真正的 Apple Fn/地球键事件。用户最终使用的是 Fn/地球键，不是 F24。

## App 引导流程

1. 用 USB 连接准确型号 Air65 V3，打开 NuNuBar > 键盘。
2. 在“黄色键快捷功能”的键盘图中点选黄色 `PGDN`。App 会分开显示实体键位
   `PGDN`、传递信号 `F24` 和最终动作 `Fn/Globe`。
3. 打开 NuPhyIO。选择 Mac 模式和 M1 配置，点选实体黄色 `PGDN` 位置，设为
   `F24` 并保存；重新加载 NuPhyIO 一次，确认设置仍然存在。
   NuNuBar 目前不能读取 NuPhyIO 的内部键表，所以还要确认 N 等其他键没有重复
   使用 `F24`。
4. 只从 [Karabiner 官方网站](https://karabiner-elements.pqrs.org/)安装
   Karabiner-Elements。按其 Setup 页面完成两个后台项目、辅助功能、输入捕获和
   DriverKit 扩展授权。
5. 回到 NuNuBar。App 检测到 Karabiner 后显示“配置”。任何写入前都会在确认框
   中列出准确目标 `~/.config/karabiner/karabiner.json` 和同目录时间戳 `.bak`
   备份路径。
6. 用户确认后，NuNuBar 只向当前 profile 合并一条规则，保留其他 profile、规则
   和原文件权限。
7. 打开“按键验收”，按一次黄色键。EventViewer 必须显示虚拟键盘输出的
   `keyboard_fn` down/up。

规则仅匹配 vendor `6645`（`19F5`）、product `4139`（`102B`）和键盘接口，
不会影响 Mac 内置键盘或其他 NuPhy 型号。

## 恢复

在 NuNuBar 的映射选项菜单中选择“移除映射”，App 会先创建另一份时间戳备份，
再只删除 NuNuBar 管理的规则。随后回到 NuPhyIO，把实体黄色键从 `F24` 恢复为
`PGDN`。只有在之后没有新增 Karabiner 设置时，才适合整份恢复旧备份。

这个功能绝不需要进入 DFU，也不能刷入 V2 固件。键盘侧设置保存后，蓝牙仍可用于
普通打字；但当前完成验证的设置过程和 Air65 V3 状态灯仍然以有线 USB 为准。
