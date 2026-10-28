import SwiftUI

struct FloatingView: View {
    @AppStorage(AppTheme.storageKey) private var appearanceTheme: AppTheme = .dark
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    static let size = CGSize(width: 220, height: 44)
    @ObservedObject var store: StatisticsStore
    @ObservedObject var monitor: InputMonitor
    var expand: () -> Void
    var hide: () -> Void

    private var status: String {
        store.paused ? "已暂停" : monitor.listening ? "今日统计" : "等待输入监控权限"
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "cursorarrow.motionlines").font(.system(size: 12))
                Text(distanceParts(store.today.distanceMeters).0)
                    .font(.system(size: 16, weight: .medium, design: .rounded)).monospacedDigit()
                Text(distanceParts(store.today.distanceMeters).1).font(.system(size: 10))
            }
            .foregroundColor(Theme.mint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("今日鼠标距离 \(distanceParts(store.today.distanceMeters).0) \(distanceParts(store.today.distanceMeters).1)")
            Rectangle().fill(Theme.line).frame(width: 1, height: 17)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "keyboard").font(.system(size: 12))
                Text(number(store.today.totalKeys))
                    .font(.system(size: 16, weight: .medium, design: .rounded)).monospacedDigit()
                Text("次").font(.system(size: 10))
            }
            .foregroundColor(Theme.blue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("今日键盘输入 \(store.today.totalKeys) 次")
        }
        .lineLimit(1).minimumScaleFactor(0.6)
        .padding(.horizontal, 13)
        .frame(width: Self.size.width, height: Self.size.height)
        .background {
            if reduceTransparency {
                Theme.background
            } else {
                ZStack {
                    DesktopGlass()
                    Theme.background.opacity(appearanceTheme == .light ? 0.76 : 0.82)
                    LinearGradient(colors: [.white.opacity(appearanceTheme == .light ? 0.2 : 0.025), .clear], startPoint: .top, endPoint: .bottom)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(store.paused ? Color.orange.opacity(0.55) : Theme.line, lineWidth: 1))
        .contentShape(Rectangle())
        .contextMenu {
            Text(status)
            Divider()
            Button("展开统计面板", action: expand)
            Button(store.paused ? "继续统计" : "暂停统计") { store.paused.toggle() }
            Button("隐藏到菜单栏", action: hide)
        }
        .help("\(status) · 距离 / 键盘输入次数\n拖动可移动，右键打开操作菜单")
        .preferredColorScheme(appearanceTheme.colorScheme)
    }
}
