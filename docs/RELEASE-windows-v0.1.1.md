# 迹 · Trace for Windows 0.1.1

修复 Windows Server 2019 / Windows 10 1809 的系统版本兼容性检查。

## 修复内容

0.1.0 安装器将最低内部版本限制为 19045，应用 SDK 目标为 19041，因此会拒绝 Server 2019 的 17763 系统。0.1.1 将应用 SDK 目标和安装器基线统一到 **10.0.17763（1809）**，不只修改安装器的放行条件。

最低系统版本与应用版本集中在 `windows/Compatibility.props`，增加针对 **17763.3532** 的配置回归检查，防止两者再次不一致。

## 下载

- **Windows Server 2019 / Intel / AMD 电脑**：`Trace-0.1.1-windows-x64-setup.exe`。
- ARM64 电脑：`Trace-0.1.1-windows-arm64-setup.exe`。
- 也提供对应架构的 `portable.zip` 和 `SHA256SUMS-windows-<架构>.txt`。

下载新版运行即可；如果旧版在安装前已经报错，不需要卸载。安装器与便携版自带 .NET 运行时，更新不主动删除本地统计。

支持具有桌面体验的 Windows Server 2019 及以上（x64）、Windows 10 1809 及以上、Windows 11。不支持无桌面的 Server Core / Nano Server，也不采样其他登录用户的会话。

## 验证范围

云端执行系统版本基线回归、核心逻辑、两套主题渲染、程序启动 / 原生接口 / 窗口切换检查及 x64 安装 / 卸载检查。**尚未在内部版本 17763 的 Server 2019 真机上完成运行验证**；ARM64 也仍需对应真机验证。

保留原有功能：半透明悬浮条、鼠标距离、键盘次数与热力图、可选本地中英文词语画像、双主题、应用排除及 JSON 导出。

当前程序和安装器未进行商业代码签名。校验下载文件可使用 `Get-FileHash <文件名> -Algorithm SHA256`，与同架构的 SHA256SUMS 清单对比。请按 Windows 正常流程决定是否运行，无需关闭系统安全保护。

[Windows 中文指南](https://github.com/aiyougit/trace/blob/main/windows/README.md)
