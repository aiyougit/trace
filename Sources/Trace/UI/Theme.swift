import SwiftUI
import AppKit

enum AppTheme: String, CaseIterable, Identifiable {
    case dark, light
    static let storageKey = "appearanceTheme"
    var id: String { rawValue }
    var colorScheme: ColorScheme { self == .light ? .light : .dark }
    var appearance: NSAppearance? { NSAppearance(named: self == .light ? .aqua : .darkAqua) }
    var title: String { self == .light ? "浅色 · 淡木" : "深色 · 夜色" }
    var detail: String { self == .light ? "浅黄木色，温暖而清淡" : "深墨底色，安静而专注" }
    var previewBackground: Color { Color(hex: self == .light ? 0xF6F0E3 : 0x101619) }
    var previewSidebar: Color { Color(hex: self == .light ? 0xEDE4D2 : 0x0C1114) }
    var previewCard: Color { Color(hex: self == .light ? 0xFFFBF2 : 0x182125) }
    var previewAccent: Color { Color(hex: self == .light ? 0x727C55 : 0x9DE8CC) }
}

enum Theme {
    static let background = adaptive(light: 0xF6F0E3, dark: 0x101619)
    static let sidebar = adaptive(light: 0xEDE4D2, dark: 0x0C1114)
    static let card = adaptive(light: 0xFFFBF2, dark: 0x182125)
    static let text = adaptive(light: 0x4D4639, dark: 0xF5F7F6)
    static let line = adaptive(light: 0x786341, dark: 0xFFFFFF, lightAlpha: 0.13, darkAlpha: 0.07)
    static let quietFill = adaptive(light: 0x786341, dark: 0xFFFFFF, lightAlpha: 0.055, darkAlpha: 0.045)
    static let mint = adaptive(light: 0x68764B, dark: 0x9DE8CC)
    static let blue = adaptive(light: 0x967044, dark: 0xA4C8F5)
    static let lilac = adaptive(light: 0x8B7168, dark: 0xC9BAF0)
    static let muted = adaptive(light: 0x7E705D, dark: 0x829297)
    static let heatmapLabel = adaptive(light: 0xFFFBF2, dark: 0x0C1114)

    private static func adaptive(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255,
                           alpha: isDark ? darkAlpha : lightAlpha)
        })
    }
}

/// A desktop material that stays active when the floating panel is not key.
struct DesktopGlass: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = colorScheme == .light ? .popover : .hudWindow
        view.appearance = NSAppearance(named: colorScheme == .light ? .aqua : .darkAqua)
    }
}
extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}
extension View {
    func cardStyle() -> some View {
        frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
    }
}
func number(_ value: Int) -> String { value.formatted(.number.locale(Locale(identifier: "en_US"))) }
func distanceParts(_ meters: Double) -> (String, String) {
    meters >= 1000 ? (String(format: "%.2f", meters / 1000), "km") : (String(format: "%.2f", meters), "m")
}

struct TraceMark: View {
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28).fill(Theme.mint)
            Image(systemName: "cursorarrow.motionlines").font(.system(size: size * 0.55, weight: .semibold)).foregroundColor(Theme.sidebar)
        }.frame(width: size, height: size)
    }
}

struct SectionLabel: View {
    var title: String
    var subtitle: String = ""
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 15, weight: .semibold))
            Spacer()
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.muted) }
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 27, weight: .light)).foregroundColor(Theme.mint).padding(.bottom, 2)
            Text(title).font(.system(size: 14, weight: .medium))
            Text(detail).font(.system(size: 12)).foregroundColor(Theme.muted).multilineTextAlignment(.center).lineSpacing(4)
        }.frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

struct WordFlow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 400, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(width: bounds.width, subviews: subviews)
        for (i, point) in layout.points.enumerated() { subviews[i].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified) }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
