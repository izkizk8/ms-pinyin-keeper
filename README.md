# ms-pinyin-keeper

让微软拼音的 **中/英文模式** 全局记忆，切换窗口时不再被重置。

## 问题背景

Windows 自带的微软拼音输入法在切换窗口时会自动把中/英模式重置为中文，破坏了用户的输入习惯。例如你按 Shift 切到英文模式写代码，切走再切回来，IME 又变回了中文模式。

## 工作原理

- 维护一个全局布尔状态 `desired_en` (EN/CN)，持久化到 `%LOCALAPPDATA%\ms-pinyin-keeper\config.ini`
- 你按 Shift 切换时，状态翻转
- 每 80ms 检测前台窗口；窗口变化或刚切过 Shift 后的 600ms 内，通过 `WM_IME_CONTROL` / `IMC_SETCONVERSIONMODE` **直接写入**目标窗口的期望模式 (EN=0 / CN=1)
- 写入是**幂等且静默**的 — 已经是 EN 的窗口再写 EN 不会变化，不会像模拟 Shift 那样误触发 toggle
- 不读 IME 真实状态 (TSF 拼音不支持读取)，写入即可

## 安装

1. 从 [Releases](https://github.com/izkizk8/ms-pinyin-keeper/releases/latest) 下载最新的 `ms-pinyin-keeper-vX.Y.Z.zip`
2. 解压到任意目录（建议 `C:\Tools\ms-pinyin-keeper\`）
3. 双击 `App.bat` 启动
4. 右键托盘图标 → **Run at startup** 设置开机自启

无需安装 AutoHotkey，运行时已包含在 zip 中。

## 托盘菜单

- **左键单击图标**：暂停 / 恢复
- **右键菜单**：
  - Run at startup —— 开机自启
  - Auto check for updates —— 启动时和每 24h 自动检查
  - Check for updates now —— 手动检查
  - About / Exit

## 已知限制

- **JetBrains IDE**：JBR 窗口对 IME API 兼容性差，可能纠正失败（计划在后续版本通过 Java Access Bridge 解决）
- **UWP / 部分沙箱应用**：读不到 IME 状态时脚本会优雅跳过，不会乱按 Shift
- 仅针对微软拼音设计；对其他基于 IMM 的输入法（如微信输入法）理论可用，不做兼容性承诺

## 配置文件

位于 `%LOCALAPPDATA%\ms-pinyin-keeper\config.ini`，由托盘菜单管理，无需手动编辑。

## 开发者

- 源码用 AutoHotkey v2 编写
- 仓库不包含 `AutoHotkey64.exe`；release zip 由 GitHub Actions 在打 tag 时下载 `ahk-version.txt` 指定的官方版本组装而成
- 发布新版本：
  ```bash
  # 更新 src/version.txt 内容为 X.Y.Z
  git tag vX.Y.Z
  git push origin vX.Y.Z
  ```
  workflow 会自动构建并发布

## 许可

MIT
