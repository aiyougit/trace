import AppKit
import ApplicationServices
import Combine

final class InputMonitor: ObservableObject {
    @Published private(set) var inputGranted = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var listening = false
    @Published private(set) var textStatus = "词语画像已关闭"
    private let store: StatisticsStore
    private var eventTap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var nextPermissionCheck = Date.distantPast
    private var nextTapAttempt = Date.distantPast
    private var lastPoint: CGPoint?
    private var pendingMeters: Double = 0
    private var screens: [ScreenGeometry] = []
    private var field: AXUIElement?
    private var draft: TextDraft?
    private var contributedWords: [String: Int] = [:]
    private var contributedCharacters = 0
    private var contributionDay = SavedStatistics.dayKey()
    private var sampleAfter = Date.distantFuture
    private var suppressTextUntil = Date.distantPast
    private var cancellables = Set<AnyCancellable>()
    private var displayObserver: NSObjectProtocol?

    init(store: StatisticsStore, startsMonitoring: Bool = true) {
        self.store = store
        guard startsMonitoring else { return }
        refreshScreens()
        displayObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshScreens() }
        store.$paused.dropFirst().sink { [weak self] _ in
            self?.lastPoint = nil; self?.pendingMeters = 0; self?.resetText()
        }.store(in: &cancellables)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        refreshPermissions()
    }
    deinit {
        timer?.invalidate()
        if let eventTap { CFMachPortInvalidate(eventTap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
    }
    func refreshPermissions() {
        let input = CGPreflightListenEventAccess(), accessibility = AXIsProcessTrusted()
        if input != inputGranted { inputGranted = input }
        if accessibility != accessibilityGranted { accessibilityGranted = accessibility }
        if inputGranted && eventTap == nil && Date() >= nextTapAttempt {
            start()
            nextTapAttempt = Date().addingTimeInterval(5)
        }
        if !inputGranted && eventTap != nil { stop() }
        if let eventTap {
            if !CGEvent.tapIsEnabled(tap: eventTap) { CGEvent.tapEnable(tap: eventTap, enable: true) }
            let enabled = CGEvent.tapIsEnabled(tap: eventTap)
            if listening != enabled { listening = enabled }
        }
    }
    func requestInput() { _ = CGRequestListenEventAccess(); openPrivacy("ListenEvent") }
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Accessibility")
    }
    private func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)") { NSWorkspace.shared.open(url) }
    }
    private func refreshScreens() {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        screens = ids.prefix(Int(count)).map { ScreenGeometry(bounds: CGDisplayBounds($0), millimeters: CGDisplayScreenSize($0)) }
        lastPoint = nil
    }
    private func start() {
        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .keyDown, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            Unmanaged<InputMonitor>.fromOpaque(context).takeUnretainedValue().receive(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }, userInfo: context) else { listening = false; return }
        eventTap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        listening = true
    }
    func stop() {
        flushDistance()
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false); CFMachPortInvalidate(eventTap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        eventTap = nil; source = nil; listening = false; lastPoint = nil; resetText()
    }
    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return
        }
        guard !store.paused else { lastPoint = nil; return }
        if [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged].contains(type) {
            let point = event.location
            if let previous = lastPoint, let screen = screens.first(where: { $0.bounds.contains(point) }),
               screen.bounds.contains(previous) {
                pendingMeters += screen.distance(from: previous, to: point)
            }
            lastPoint = point
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let id = app.bundleIdentifier ?? ""
        guard !store.excludedBundleIDs.contains(id) else { resetText(); return }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .flagsChanged {
            if code == 57 || CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(code)) {
                store.record(key: KeyNames.name(for: code))
            }
            return
        }
        // Count physical presses; holding a key does not inflate frequency via repeats.
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { store.record(key: KeyNames.name(for: code)) }
        guard store.wordTrackingEnabled, accessibilityGranted else { return }
        if event.flags.contains(.maskCommand), code == 9 {
            resetText(); suppressTextUntil = Date().addingTimeInterval(1)
            return
        }
        // Capture the pre-edit baseline when a field first receives a keystroke.
        if Date() >= suppressTextUntil { sampleText(app: app, baselineOnly: true) }
        sampleAfter = Date().addingTimeInterval(0.65)
    }
    private func flushDistance() {
        if pendingMeters > 0 { store.record(distance: pendingMeters); pendingMeters = 0 }
    }
    private func tick() {
        flushDistance()
        if Date() >= nextPermissionCheck {
            refreshPermissions(); nextPermissionCheck = Date().addingTimeInterval(2)
        }
        guard !store.paused, store.wordTrackingEnabled else {
            if field != nil { resetText() }
            let status = store.paused ? "统计已暂停" : "词语画像已关闭"
            if textStatus != status { textStatus = status }
            return
        }
        guard accessibilityGranted else { resetText(); textStatus = "等待辅助功能权限"; return }
        guard !IsSecureEventInputEnabled() else { resetText(); textStatus = "安全输入中，已跳过"; return }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !store.excludedBundleIDs.contains(app.bundleIdentifier ?? "") else {
            resetText(); textStatus = "当前应用已跳过"; return
        }
        if Date() < suppressTextUntil { resetText(); return }
        if Date() >= sampleAfter {
            sampleAfter = .distantFuture
            sampleText(app: app, baselineOnly: false)
        } else {
            // Refresh focus baseline without reading changes in the existing field.
            sampleText(app: app, baselineOnly: true)
        }
    }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success ? result : nil
    }
    private func sampleText(app: NSRunningApplication, baselineOnly: Bool) {
        guard !IsSecureEventInputEnabled() else { resetText(); return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(axApp, 0.05)
        guard let ref = attribute(axApp, kAXFocusedUIElementAttribute), CFGetTypeID(ref) == AXUIElementGetTypeID() else {
            resetText(); textStatus = "此应用未提供可读取的输入框"; return
        }
        let focused = unsafeBitCast(ref, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(focused, 0.05)
        let role = attribute(focused, kAXRoleAttribute) as? String ?? ""
        let subrole = attribute(focused, kAXSubroleAttribute) as? String ?? ""
        let protected = attribute(focused, "AXProtectedContent") as? Bool ?? false
        guard [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role),
              subrole != kAXSecureTextFieldSubrole, !protected else {
            resetText(); textStatus = "非文本框或受保护输入，已跳过"; return
        }
        let sameField = field.map { CFEqual($0, focused) } ?? false
        if sameField && baselineOnly { return }
        guard let value = attribute(focused, kAXValueAttribute) as? String, value.utf16.count <= 30_000 else {
            resetText(); textStatus = "此输入框不支持词语统计"; return
        }
        if !sameField || contributionDay != SavedStatistics.dayKey() {
            resetText(); field = focused; draft = TextDraft(baseline: value)
        } else if !baselineOnly, var current = draft {
            current.update(value); draft = current
            let typed = current.insertedText
            let words = Dictionary(TextAnalysis.words(in: typed).map { ($0, 1) }, uniquingKeysWith: +)
            let chars = typed.filter { !$0.isWhitespace }.count
            store.reviseWords(from: contributedWords, to: words, characterDelta: chars - contributedCharacters)
            contributedWords = words; contributedCharacters = chars
        }
        textStatus = "本地分析 · \(app.localizedName ?? "当前应用")"
    }
    func resetText() {
        field = nil; draft = nil; contributedWords = [:]; contributedCharacters = 0
        contributionDay = SavedStatistics.dayKey(); sampleAfter = .distantFuture
    }
}

import Carbon
