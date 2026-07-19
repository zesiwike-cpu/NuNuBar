# Third-party notices

NuNuBar bundles small Agent brand images only to identify integrations in the
local settings UI. Those names, logos, and trademarks remain the property of
their respective owners and are not licensed under NuNuBar's MIT license.

| Asset | Source |
|---|---|
| Codex / OpenAI | [OpenAI brand guidelines](https://openai.com/brand/) and the OpenAI provider asset in the official [OpenCode repository](https://github.com/anomalyco/opencode) |
| Claude Code | Official [Anthropic Claude Code VS Code extension](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code) |
| Antigravity | Icon from the official [Google Antigravity](https://antigravity.google/) macOS application bundle |
| OpenCode | [OpenCode brand page](https://opencode.ai/brand) and official [OpenCode repository](https://github.com/anomalyco/opencode) |
| Grok | [Grok favicon](https://grok.com/images/favicon.svg) |
| Hermes | Official [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) repository |
| OpenClaw | Official [openclaw/openclaw](https://github.com/openclaw/openclaw) repository |

The firmware patches link against and modify NuPhy/QMK firmware behavior. The
firmware directory is distributed under GPL-2.0-or-later and preserves the
original NuPhy/QMK licensing boundary. NuPhy's official source is available at
[nuphy-src/qmk_firmware](https://github.com/nuphy-src/qmk_firmware).

The macOS setup package includes `dfu-util` (GPL-2.0-or-later) and `libusb`
(LGPL-2.1-or-later) for local STM32 DFU access. Their source locations and
license texts are recorded in the app's bundled open-source notices.

Windows release executables are packaged with CPython and PyInstaller. CPython
is distributed under the Python Software Foundation License; PyInstaller is
GPL-2.0-or-later with its bootloader exception, which permits distributing the
resulting executable under this project's license. See the upstream projects
for complete notices and corresponding source:

- [Python](https://www.python.org/downloads/source/)
- [PyInstaller](https://github.com/pyinstaller/pyinstaller)

NuNuBar is not affiliated with or endorsed by NuPhy, OpenAI, Anthropic, Google,
xAI, OpenCode, Nous Research, or OpenClaw.

The Air65 V3 official-HID protocol integration was adapted from the MIT-licensed
`Air65 V3 Codex Light` reference implementation supplied with this project.
Copyright (c) 2026 Air65 V3 Codex Light contributors. Its license text is
included in the application bundle.
