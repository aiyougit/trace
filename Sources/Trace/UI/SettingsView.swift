import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(AppTheme.storageKey) private var appearanceTheme: AppTheme = .dark
    @ObservedObject var store: StatisticsStore
    @ObservedObject var monitor: InputMonitor
    var restart: () -> Void = {}
    @State private var clearTarget: String?
    @State private var exportMessage: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(title: "外观主题", subtitle: "面板与悬浮条同步切换")
                HStack(spacing: 14) {
                    ForEach([AppTheme.light, .dark]) { theme in
                        themeOption(theme)
                    }
                }
                Text("悬浮条带有轻微的磨砂透明感，文字保持清晰。主题会自动记住。").font(.system(size: 11)).foregroundColor(Theme.muted)
            }.cardStyle()
            VStack(alignment: .leading, spacing: 18) {
                SectionLabel(title: "系统权限", subtitle: "由你决定开启什么")
                permissionRow("输入监控", detail: monitor.inputGranted ? (monitor.listening ? "监听已连接，正在统计鼠标轨迹和按键次数。" : "系统报告已授权，但监听未启动，请退出并重新打开。") : "当前版本的授权尚未生效，暂时无法统计鼠标和键盘。", granted: monitor.inputGranted, action: monitor.requestInput)
                Divider().overlay(Theme.line)
                permissionRow("辅助功能", detail: "仅开启词语画像时需要，用于识别输入框中提交的文字。", granted: monitor.accessibilityGranted, action: monitor.requestAccessibility)
                HStack {
                    Text("授权后需完全退出再打开，关闭窗口不会退出应用。").font(.system(size: 10)).foregroundColor(Theme.muted)
                    Spacer()
                    Button("重新检测") { monitor.refreshPermissions() }.font(.system(size: 11))
                }
                if !monitor.inputGranted || !monitor.accessibilityGranted || !monitor.listening {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("系统开关已打开，应用仍显示未生效？").font(.system(size: 12, weight: .medium))
                        Text("先退出并重新打开。若仍无效，在对应权限列表选中旧 Trace，点击减号移除，再用加号重新添加下方位置的 Trace 并开启。开发版更新签名后，旧授权可能失效；不用卸载或清空统计。").font(.system(size: 11)).foregroundColor(Theme.muted).lineSpacing(4)
                        Text(Bundle.main.bundleURL.path).font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.mint).textSelection(.enabled)
                        HStack {
                            Button("退出并重新打开", action: restart)
                            Button("在访达中定位应用") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
                        }.font(.system(size: 11))
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Theme.mint.opacity(0.04)).cornerRadius(10)
                }
            }.cardStyle()
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: Binding(get: { store.wordTrackingEnabled }, set: { value in monitor.resetText(); store.setWordTracking(value) })) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("词语画像").font(.system(size: 14, weight: .semibold))
                        Text("分析新增文字的中英文词频，不保存原始输入记录。").font(.system(size: 11)).foregroundColor(Theme.muted)
                    }
                }.toggleStyle(.switch).tint(Theme.mint)
                Text("系统标记的密码框和安全输入会被跳过。自定义输入框未必提供安全标记；处理敏感内容时，请暂停统计或排除该应用。").font(.system(size: 11)).foregroundColor(Theme.muted).lineSpacing(4)
                HStack(spacing: 7) {
                    Circle().fill(store.wordTrackingEnabled && monitor.accessibilityGranted ? Theme.mint : Theme.muted).frame(width: 5, height: 5)
                    Text(monitor.textStatus).font(.system(size: 10)).foregroundColor(Theme.muted)
                }
            }.cardStyle()
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(title: "排除应用", subtitle: "跳过这些应用的按键和词语统计")
                Text("已默认排除常见密码管理器和终端。鼠标距离仍会累计。").font(.system(size: 11)).foregroundColor(Theme.muted)
                ForEach(store.excludedBundleIDs, id: \.self) { id in
                    HStack {
                        Image(systemName: "app.dashed").foregroundColor(Theme.muted)
                        Text(appName(id)).font(.system(size: 11)).lineLimit(1)
                        Spacer()
                        Button { store.removeExcludedApp(id); monitor.resetText() } label: { Image(systemName: "xmark").font(.system(size: 10)) }.buttonStyle(.plain).foregroundColor(Theme.muted).help("移出排除列表")
                    }
                }
                Button { chooseApp() } label: { Label("添加应用…", systemImage: "plus") }.font(.system(size: 11)).buttonStyle(.bordered)
            }.cardStyle()
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(title: "本地数据")
                Text("统计按天存储，每 10 秒自动保存；退出时立即保存。没有联网、云端上传或后台服务。").font(.system(size: 11)).foregroundColor(Theme.muted).lineSpacing(4)
                HStack(spacing: 12) {
                    Button("导出统计…", action: export)
                    Button("打开数据目录") { NSWorkspace.shared.open(store.fileURL.deletingLastPathComponent()) }
                    Spacer()
                }.font(.system(size: 11))
                HStack(spacing: 12) {
                    Button("清空词语画像…") { clearTarget = "words" }
                    Button("清空全部统计…") { clearTarget = "all" }
                }.font(.system(size: 11)).foregroundColor(.orange)
                if store.storageError != nil {
                    Button("备份原文件并重试保存") { store.resetStorageError() }.font(.system(size: 11))
                }
            }.cardStyle()
            Text("迹 TRACE  ·  v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0")  ·  macOS 原生应用").font(.system(size: 10)).foregroundColor(Theme.muted).frame(maxWidth: .infinity)
        }
        .alert(clearTarget == "words" ? "清空所有词语画像？" : "清空全部历史统计？", isPresented: Binding(get: { clearTarget != nil }, set: { if !$0 { clearTarget = nil } })) {
            Button("取消", role: .cancel) { clearTarget = nil }
            Button("确认清空", role: .destructive) {
                monitor.resetText()
                if clearTarget == "words" { store.clearWords() } else { store.clearAll() }
                clearTarget = nil
            }
        } message: { Text("此操作会删除所有日期范围内的对应统计，无法撤销。") }
        .alert("导出统计", isPresented: Binding(get: { exportMessage != nil }, set: { if !$0 { exportMessage = nil } })) {
            Button("好") { exportMessage = nil }
        } message: { Text(exportMessage ?? "") }
    }
    private func themeOption(_ theme: AppTheme) -> some View {
        Button { appearanceTheme = theme } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 0) {
                    theme.previewSidebar.frame(width: 35)
                    VStack(alignment: .leading, spacing: 7) {
                        Capsule().fill(theme.previewAccent.opacity(0.65)).frame(width: 64, height: 5)
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 5).fill(theme.previewCard)
                            RoundedRectangle(cornerRadius: 5).fill(theme.previewCard)
                        }.frame(height: 30)
                        Capsule().fill(theme.previewAccent.opacity(0.18)).frame(height: 6)
                    }.padding(12).frame(maxWidth: .infinity)
                }.frame(height: 86).background(theme.previewBackground).clipShape(RoundedRectangle(cornerRadius: 9))
                HStack {
                    Image(systemName: theme == .light ? "sun.max" : "moon")
                    Text(theme.title).font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: appearanceTheme == theme ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(appearanceTheme == theme ? Theme.mint : Theme.muted.opacity(0.5))
                }
                Text(theme.detail).font(.system(size: 10)).foregroundColor(Theme.muted)
            }.padding(12).foregroundColor(Theme.text)
                .background(appearanceTheme == theme ? Theme.mint.opacity(0.045) : .clear)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(appearanceTheme == theme ? Theme.mint.opacity(0.65) : Theme.line, lineWidth: 1))
        }.buttonStyle(.plain)
            .accessibilityLabel(theme.title)
            .accessibilityValue(appearanceTheme == theme ? "已选中" : "未选中")
    }
    private func permissionRow(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: granted ? "checkmark.shield.fill" : "lock.shield").foregroundColor(granted ? Theme.mint : Theme.muted).font(.system(size: 22)).frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundColor(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(granted ? "已授权 · 管理" : "未生效 · 去设置", action: action).font(.system(size: 11)).buttonStyle(.bordered).tint(granted ? Theme.mint : Theme.blue)
        }
    }
    private func appName(_ id: String) -> String {
        if let name = store.data.excludedAppNames[id] { return name }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id), let bundle = Bundle(url: url) {
            return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? id
        }
        let names = ["com.apple.Terminal":"终端", "com.googlecode.iterm2":"iTerm2", "com.apple.Passwords":"密码", "com.apple.keychainaccess":"钥匙串访问", "com.1password.1password":"1Password", "com.agilebits.onepassword7":"1Password 7", "com.bitwarden.desktop":"Bitwarden", "org.keepassxc.keepassxc":"KeePassXC"]
        return names[id] ?? id
    }
    private func chooseApp() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.message = "选择要排除的应用"
        if panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let id = bundle.bundleIdentifier {
            store.addExcludedBundle(id, name: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent)
            monitor.resetText()
        }
    }
    private func export() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Trace-\(SavedStatistics.dayKey()).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(store.data).write(to: url, options: .atomic)
            exportMessage = "统计已导出。文件包含按天汇总的鼠标距离、按键次数和词频。"
        } catch { exportMessage = "导出失败：\(error.localizedDescription)" }
    }
}
