# 迹 · Trace for Windows 0.1.0

首个 Windows 预览版本，原生 .NET 10 / WPF 实现，沿用 macOS 版的淡木 / 夜色设计。

## 下载哪个文件？

| 电脑类型 | 推荐安装包 | 便携版 |
| --- | --- | --- |
| Intel / AMD 64 位电脑 | `Trace-0.1.0-windows-x64-setup.exe` | `Trace-0.1.0-windows-x64-portable.zip` |
| ARM64 / Snapdragon 电脑 | `Trace-0.1.0-windows-arm64-setup.exe` | `Trace-0.1.0-windows-arm64-portable.zip` |

支持 Windows 10 22H2（19045）/ Windows 11，不支持 32 位 Windows。下载并运行 setup.exe，或解压便携 ZIP 后运行 Trace.exe。两者均自带 .NET 运行时，无需另装 .NET。

安装器按当前用户安装到 `%LOCALAPPDATA%\Programs\Trace`，创建开始菜单入口和卸载项，桌面快捷方式可选。不安装服务、不设置开机启动；更新及卸载不主动删除 `%LOCALAPPDATA%\Trace` 里的统计。

## 主要功能

- 220 × 44 DIP 半透明悬浮条，只显示今日鼠标距离和键盘输入次数；拖动移动、双击展开、右键菜单。
- 正常层级的统计面板，只有悬浮条置顶；切换其他应用、最小化或关闭后自动收起，任务栏和托盘均可恢复。
- 今天 / 累计、每小时活动、按键热力图与排行。
- 可选中英文词语画像，默认关闭；UI Automation 观察受支持的编辑输入框，使用程序附带的本地中文词典分词，不依赖 Windows 中文语言包。
- 淡木 / 夜色两套主题，悬浮条同步切换，保留选择。
- 按进程排除、全局暂停、JSON 导出、数据清理及损坏文件保护。
- 本机保存，不联网、不遥测，不保存原始段落、按键顺序、剪贴板或输入时间线。

## 校验下载

Release 提供两个架构各自的 `SHA256SUMS-windows-<架构>.txt`。在 PowerShell 计算对应文件的 SHA-256，与清单逐项核对：

```powershell
Get-FileHash .\Trace-0.1.0-windows-x64-setup.exe -Algorithm SHA256
```

## 已知限制

- 当前程序及安装器没有商业代码签名，可能显示 SmartScreen / 未知发布者提示。请核对仓库来源和校验和，并按 Windows 正常流程决定是否运行；无需关闭系统安全保护。
- 鼠标距离是屏幕光标路径估算，依赖显示驱动的物理尺寸；不是实体鼠标在桌面上的行程。
- 密码标记与应用兼容性依赖 UI Automation。自定义输入框、浏览器、管理员程序、中文输入法、粘贴及快速编辑可能造成漏记或误归因；敏感内容请暂停或排除应用。
- 本地中文词典按 MIT 许可随程序再分发。未知词可能拆分或被过滤；词频画像不等于完整文本记录。
- Windows CI 已验证核心逻辑、WPF 渲染、原生监听接口初始化与清理、本地分词、应用启动 / 任务栏 / 悬浮模式切换、自带运行时打包，以及 x64 安装 / 卸载。真实鼠标键盘、中文输入法和不同应用的采样表现仍需真机体验；ARM64 已交叉构建，尚未完成 ARM64 真机运行验证。

[完整中文 Windows 指南与截图](https://github.com/aiyougit/trace-macos/blob/main/windows/README.md) · [项目主页](https://github.com/aiyougit/trace-macos)
