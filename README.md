# ms-pinyin-keeper

让微软拼音的 **中/英文模式** 全局记忆，切换窗口时不再被重置。

## 问题背景

Windows 自带的微软拼音输入法在切换窗口时会自动把中/英模式重置为中文，破坏了用户的输入习惯。例如你按 Shift 切到英文模式写代码，切走再切回来，IME 又变回了中文模式。

## 工作原理

- 维护一个全局布尔状态 `desired_en` (EN/CN)，持久化到 `%LOCALAPPDATA%\ms-pinyin-keeper\config.ini`
- 你按 Shift 切换时，状态翻转
- 每 100ms 检测前台窗口是否变化；窗口一变 (微软拼音此时已自动重置为中文)，如果你的状态是 EN，立即模拟一次 Shift 把它切回英文
- 不读 IME 真实状态 (TSF 拼音不支持) ，逻辑简单可靠

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
