import SwiftUI
import AppKit
import Combine

@main
struct TraceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

final class DashboardWindow: NSWindow {
    var onMinimize: (() -> Void)?
    override func performMiniaturize(_ sender: Any?) {
        if let onMinimize { onMinimize() } else { super.performMiniaturize(sender) }
    }
    override func miniaturize(_ sender: Any?) {
        if let onMinimize { onMinimize() } else { super.miniaturize(sender) }
    }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = StatisticsStore()
    private lazy var monitor = InputMonitor(store: store)
    private var dashboard: DashboardWindow!
    private var floatingPanel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private var isCompact = false
    private var isTerminating = false
    private var appliedTheme: AppTheme?
    private var pauseMenuItem: NSMenuItem!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMenu()
        configureWindows()
        updateAppearance()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateAppearance() }
            .store(in: &cancellables)
        let wantsCompact = CommandLine.arguments.contains("--compact") || UserDefaults.standard.bool(forKey: "compactMode")
        if wantsCompact { showCompact() } else { showDashboard() }
    }

    private func configureWindows() {
        dashboard = DashboardWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        dashboard.title = "迹 · Trace"
        dashboard.titlebarAppearsTransparent = true
        dashboard.titleVisibility = .hidden
        dashboard.isMovableByWindowBackground = true
        dashboard.isReleasedWhenClosed = false
        dashboard.level = .normal
        dashboard.collectionBehavior = [.managed]
        dashboard.backgroundColor = NSColor(Theme.background)
        dashboard.contentMinSize = NSSize(width: 940, height: 680)
        dashboard.contentMaxSize = NSSize(width: 1800, height: 1200)
        dashboard.delegate = self
        dashboard.onMinimize = { [weak self] in self?.showCompact() }
        dashboard.standardWindowButton(.miniaturizeButton)?.target = self
        dashboard.standardWindowButton(.miniaturizeButton)?.action = #selector(showCompact)
        // Keep the hosting view alive so switching apps preserves the selected page.
        dashboard.contentView = NSHostingView(rootView: DashboardView(store: store, monitor: monitor, compact: { [weak self] in self?.showCompact() }, restart: { [weak self] in self?.restartApplication() }))
        dashboard.center()

        floatingPanel = FloatingPanel(contentRect: NSRect(origin: .zero, size: FloatingView.size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        floatingPanel.title = "迹 · Trace 悬浮条"
        floatingPanel.isMovableByWindowBackground = true
        floatingPanel.hidesOnDeactivate = false
        floatingPanel.isReleasedWhenClosed = false
        floatingPanel.isFloatingPanel = true
        floatingPanel.level = .floating
        floatingPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        floatingPanel.isOpaque = false
        floatingPanel.backgroundColor = .clear
        floatingPanel.hasShadow = true
        floatingPanel.contentMinSize = FloatingView.size
        floatingPanel.contentMaxSize = FloatingView.size
        floatingPanel.contentView = NSHostingView(rootView: FloatingView(store: store, monitor: monitor, expand: { [weak self] in self?.showDashboard() }, hide: { [weak self] in self?.floatingPanel.orderOut(nil) }))
        let screen = NSScreen.main?.visibleFrame ?? .zero
        floatingPanel.setFrameOrigin(NSPoint(x: screen.maxX - FloatingView.size.width - 24, y: screen.maxY - FloatingView.size.height - 24))
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "迹 Trace")
            button.toolTip = "迹 · Trace — 你的数字足迹"
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "迹 · Trace", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        addItem("显示统计面板", action: #selector(showDashboard), to: menu)
        addItem("显示桌面悬浮窗", action: #selector(showCompact), to: menu)
        pauseMenuItem = addItem("暂停统计", action: #selector(togglePause), to: menu)
        menu.addItem(.separator())
        addItem("退出并重新打开", action: #selector(restartApplication), to: menu)
        addItem("退出 Trace", action: #selector(quit), to: menu, key: "q")
        statusItem.menu = menu
        store.$paused.sink { [weak self] paused in self?.pauseMenuItem?.title = paused ? "继续统计" : "暂停统计" }.store(in: &cancellables)
    }

    private func updateAppearance() {
        let theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: AppTheme.storageKey) ?? "") ?? .dark
        guard theme != appliedTheme else { return }
        appliedTheme = theme
        dashboard.appearance = theme.appearance
        floatingPanel.appearance = theme.appearance
        dashboard.backgroundColor = NSColor(Theme.background)
    }

    @discardableResult private func addItem(_ title: String, action: Selector, to menu: NSMenu, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc func showDashboard() {
        guard dashboard != nil, !isTerminating else { return }
        isCompact = false
        UserDefaults.standard.set(false, forKey: "compactMode")
        floatingPanel.orderOut(nil)
        if dashboard.isMiniaturized { dashboard.deminiaturize(nil) }
        dashboard.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Activate after a floating panel's context menu finishes restoring focus.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isCompact, !self.isTerminating else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.dashboard.makeKeyAndOrderFront(nil)
        }
        monitor.refreshPermissions()
    }

    @objc func showCompact() {
        guard floatingPanel != nil, !isTerminating else { return }
        isCompact = true
        UserDefaults.standard.set(true, forKey: "compactMode")
        dashboard.orderOut(nil)
        // Clamp a previously dragged panel after changing displays.
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(floatingPanel.frame) }), let screen = NSScreen.main?.visibleFrame {
            floatingPanel.setFrameOrigin(NSPoint(x: screen.maxX - FloatingView.size.width - 24, y: screen.maxY - FloatingView.size.height - 24))
        }
        floatingPanel.orderFrontRegardless()
    }

    func applicationDidResignActive(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, !self.isCompact, !self.isTerminating,
                  !NSApp.isActive, self.dashboard?.isVisible == true,
                  NSApp.modalWindow == nil, self.dashboard.attachedSheet == nil else { return }
            self.showCompact()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) { monitor.refreshPermissions() }

    @objc private func togglePause() { store.paused.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func restartApplication() {
        guard !isTerminating else { return }
        isTerminating = true
        monitor.stop()
        store.save()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.isTerminating = false
                    self.monitor.refreshPermissions()
                    let alert = NSAlert()
                    alert.messageText = "重新打开失败"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                } else { NSApp.terminate(nil) }
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { showCompact(); return false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showDashboard(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { isTerminating = true; return .terminateNow }
    func applicationWillTerminate(_ notification: Notification) { monitor.stop(); store.save() }
}
