# 迹 · Trace for Windows

原生 WPF 版本，支持 **Windows 10 22H2（19045）/ Windows 11**，提供 x64 与 ARM64 构建。旧的 32 位 Windows 不支持。与 macOS 使用相同的产品设计，各平台分别使用系统原生界面与输入接口。

## 界面预览

所有截图使用虚构演示数据，由 Windows 原生 WPF 渲染，不启动监听。

![Windows 淡木概览](../docs/images/overview-windows-light.png)

| 夜色键盘热力 | 淡木词语画像 |
| --- | --- |
| ![键盘热力](../docs/images/keyboard-windows-dark.png) | ![词语画像](../docs/images/words-windows-light.png) |

| 淡木悬浮条 | 夜色悬浮条 |
| --- | --- |
| <img src="../docs/images/floating-windows-light.png" width="220" alt="淡木悬浮条"> | <img src="../docs/images/floating-windows-dark.png" width="220" alt="夜色悬浮条"> |

## 下载与安装

从 [Windows 版本发布页](https://github.com/aiyougit/trace-macos/releases/tag/windows-v0.1.0) 下载：

- 普通 Intel / AMD 电脑：`Trace-0.1.0-windows-x64-setup.exe`。
- Snapdragon 等 ARM 电脑：`Trace-0.1.0-windows-arm64-setup.exe`。
- 无需安装器：选择对应架构的 `portable.zip`，解压后运行 `Trace.exe`。

安装器按当前用户安装到 `%LOCALAPPDATA%\Programs\Trace`，提供开始菜单入口和卸载项，桌面快捷方式可选。程序自带 .NET 运行时，不需要另装 .NET；不安装服务、不设置开机启动。首次启动即开始本地基础统计，可在托盘菜单暂停或退出。词语画像默认关闭。

当前 EXE 和安装器没有商业代码签名证书，Windows 可能显示 SmartScreen 或未知发布者提示。请核对本仓库及 Release 的 SHA-256，按 Windows 提供的正常流程判断是否运行；不需要关闭系统安全保护。

## 窗口和外观

- 220 × 44 DIP 悬浮条只显示今日鼠标距离与键盘输入次数，支持高 DPI 缩放。
- 拖动移动，双击展开，右键暂停 / 继续、隐藏或退出。
- 主面板不置顶，切换其他应用、最小化或关闭时自动收起；文件选择器和确认对话框不触发折叠。
- 主面板收起后保留任务栏入口；任务栏点击恢复，托盘双击也可展开。Windows 可能将托盘图标放在「显示隐藏的图标」区域。
- 设置中切换「浅色 · 淡木」/「深色 · 夜色」，立即适配悬浮条并记住选择。
- 悬浮条背景轻微透明，文字保持不透明；尊重系统透明效果关闭设置。Windows 版使用半透明背景，不宣称具有 macOS 的原生磨砂效果。

## 统计口径

鼠标距离为**屏幕光标路径估算**，不是实体鼠标在桌面上的距离。通过每块显示器的 GDI 驱动毫米尺寸与物理像素坐标换算；驱动没有尺寸时按 96 PPI 估算。驱动可能返回估算尺寸，虚拟显示器、远程桌面、事件合并会影响精度。跨屏跳变不累计。界面 DPI 缩放不直接作为物理距离比例。

键盘通过 Windows 低级输入钩子统计独立按下，忽略自动重复与系统标记的注入事件；含左右修饰键、数字区和功能键。ANSI 热力图是主要键位示意，使用 Windows 键码命名，不保证适配所有键盘布局。程序不会根据按键还原文字。

默认排除常见密码管理器和终端的键盘 / 文字统计；设置可按进程文件名增删。排除不会影响鼠标距离。系统锁屏、安全桌面（例如 UAC）及会话断开时暂停采样。无法访问的进程会跳过；程序以普通用户权限运行，不尝试提升权限或读取其他用户会话。低级钩子若因系统策略或超时失效，可能需要重新启动应用。

## 可选词语画像

通过 **Windows UI Automation** 观察受支持的可编辑输入框，用 **随程序附带的本地中文词典** 进行中英文分词，不依赖系统是否安装中文语言包。词典来自 MIT 许可的 jieba 小词典，随程序打包；来源及完整许可证位于 [ThirdParty/Jieba](ThirdParty/Jieba)。中文采用词频 DAG 切分，不包含 HMM 新词识别，未知词可能拆分或被过滤。

- 默认关闭，开启后只归因观察输入框后新增的文本，已有文章不直接当作输入记录。
- 输入框基线和编辑草稿短暂保留在内存，用于修正输入法替换和删除；不写入磁盘、日志或导出文件。
- 切换输入框、日期、暂停、关闭画像、更新排除规则和清空画像会重置归因。
- 只持久化按天汇总的词语及次数、识别字符数，不保存原始段落、按键顺序、剪贴板或输入时间线。
- 跳过系统报告的密码框。密码标记检查是异步的，依赖控件正确暴露状态；自定义控件并非都能识别。处理敏感信息时请暂停或排除应用。
- 管理员程序、浏览器网页、自绘编辑器、只读文档等可能不支持；不注入应用、不截屏识字、不绕过安全桌面或进程权限。
- 稳定约 650 ms 后采样，快捷键和粘贴后暂缓归因；菜单粘贴、输入法、自动补全、焦点快速切换和复杂编辑仍可能造成遗漏或误归因。不保证记录每个字，也不提供逐字回放。
- 输入框超过 30,000 个 UTF-16 单元时跳过，每日词表最多约 5,000 项，界面展示前 80 个高频词。

## 数据与更新

统计：`%LOCALAPPDATA%\Trace\statistics.json`；主题与窗口偏好：同目录的 `preferences.json`。不联网、不遥测，退出后不再采样。每 10 秒原子保存，退出立即保存。突然断电可能丢失最近约 10 秒数据。

安装更新和卸载不会主动删除此数据目录。词频也可能包含私人信息，导出、反馈和分享截图前请检查。文件损坏时保留原文件，设置页可明确选择「备份原文件并重试保存」。

Windows 不使用 macOS 的「输入监控」「辅助功能」授权页面，通常无需重复添加应用权限。它仍受 Windows 安全策略、进程权限与安全桌面约束。

## 构建

在 Windows 安装 [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) 与 [Inno Setup 6.4+](https://jrsoftware.org/isinfo.php)，然后在 PowerShell 运行：

```powershell
dotnet run --project windows/Trace.CoreChecks -c Release
./scripts/build-windows.ps1 -Runtime win-x64
./scripts/build-windows.ps1 -Runtime win-arm64
# 只生成自带运行时的便携 ZIP，不制作安装器：
./scripts/build-windows.ps1 -Runtime win-x64 -SkipInstaller
```

输出在 `dist/windows/win-x64` 或 `dist/windows/win-arm64`，包含安装器、便携 ZIP 和 SHA-256 校验文件。x64 构建机可交叉发布 ARM64，但 ARM64 原生输入与界面行为仍需 ARM64 真机验证。

```powershell
# 独立演示数据、两种主题的界面渲染，不启动任何输入监听：
dotnet run --project windows/Trace.Windows -c Release -- --render-previews dist/windows-previews
Get-FileHash ./Trace-0.1.0-windows-x64-setup.exe -Algorithm SHA256
```

GitHub Actions 在 Windows 上执行核心检查、WPF 视图 / 主题渲染、已打包程序的原生监听接口、本地分词及应用启动 / 窗口模式检查、自带运行时发布以及 x64 安装 / 卸载检查。真实输入设备、中文输入法、不同应用的 UIA 兼容性和 ARM64 运行行为需在相应机器上体验验证。
