import AppKit
import SwiftUI

@main
struct RenderPreviews {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let previousTheme = UserDefaults.standard.object(forKey: AppTheme.storageKey)
        defer {
            if let previousTheme { UserDefaults.standard.set(previousTheme, forKey: AppTheme.storageKey) }
            else { UserDefaults.standard.removeObject(forKey: AppTheme.storageKey) }
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StatisticsStore(directory: root)
        let monitor = InputMonitor(store: store, startsMonitoring: false)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try render(DashboardView(store: store, monitor: monitor, compact: {}), size: CGSize(width: 1040, height: 760), to: output.appendingPathComponent("overview-empty.png"))
        // Synthetic fixtures exist only in this temporary preview process.
        store.record(distance: 1286.42)
        let keys = ["Space", "E", "A", "⌘", "S", "Return", "Delete", "T", "O", "N", "I", "R", "W", "D", "⇧", "C", "V", "L"]
        for (index, key) in keys.enumerated() {
            for i in 0..<(460 - index * 23) {
                let date = Calendar.current.date(bySettingHour: 7 + (i % 15), minute: 0, second: 0, of: Date())!
                store.record(key: key, at: date)
            }
        }
        store.setWordTracking(true)
        store.reviseWords(from: [:], to: ["设计": 128, "开发": 98, "软件": 76, "灵感": 64, "swift": 48, "用户体验": 35, "工作": 31, "生活": 22, "交互": 18, "trace": 15], characterDelta: 3268)
        try render(DashboardView(store: store, monitor: monitor, compact: {}), size: CGSize(width: 1040, height: 760), to: output.appendingPathComponent("overview-sample.png"))
        try render(DashboardView(store: store, monitor: monitor, compact: {}, initialTab: "键盘热力"), size: CGSize(width: 1040, height: 760), to: output.appendingPathComponent("keyboard-sample.png"))
        try render(DashboardView(store: store, monitor: monitor, compact: {}, initialTab: "词语画像"), size: CGSize(width: 1040, height: 760), to: output.appendingPathComponent("words-sample.png"))
        try render(FloatingView(store: store, monitor: monitor, expand: {}, hide: {}), size: FloatingView.size, to: output.appendingPathComponent("floating-sample.png"))
        try render(DashboardView(store: store, monitor: monitor, compact: {}, initialTab: "设置与隐私"), size: CGSize(width: 1040, height: 760), to: output.appendingPathComponent("settings.png"))
        try render(DashboardView(store: store, monitor: monitor, compact: {}), size: CGSize(width: 1040, height: 760), to: output.appendingPathComponent("overview-light.png"), theme: .light)
        try render(DashboardView(store: store, monitor: monitor, compact: {}, initialTab: "键盘热力"), size: CGSize(width: 1040, height: 760), to: output.appendingPathComponent("keyboard-light.png"), theme: .light)
        try render(DashboardView(store: store, monitor: monitor, compact: {}, initialTab: "词语画像"), size: CGSize(width: 1040, height: 760), to: output.appendingPathComponent("words-light.png"), theme: .light)
        try render(DashboardView(store: store, monitor: monitor, compact: {}, initialTab: "设置与隐私"), size: CGSize(width: 1040, height: 760), to: output.appendingPathComponent("settings-light.png"), theme: .light)
        try render(FloatingView(store: store, monitor: monitor, expand: {}, hide: {}), size: FloatingView.size, to: output.appendingPathComponent("floating-light.png"), theme: .light)
        print("Rendered previews with synthetic fixtures to \(output.path)")
    }
    @MainActor static func render<V: View>(_ view: V, size: CGSize, to url: URL, theme: AppTheme = .dark) throws {
        UserDefaults.standard.set(theme.rawValue, forKey: AppTheme.storageKey)
        let hosting = NSHostingView(rootView: view.environment(\.locale, Locale(identifier: "zh_CN")).frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.appearance = theme.appearance
        window.isOpaque = false
        window.backgroundColor = .clear
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { fatalError("Cannot create bitmap") }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode PNG") }
        try png.write(to: url)
        window.contentView = nil
    }
}
