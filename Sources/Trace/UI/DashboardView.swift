import SwiftUI
import AppKit

struct DashboardView: View {
    @AppStorage(AppTheme.storageKey) private var appearanceTheme: AppTheme = .dark
    @ObservedObject var store: StatisticsStore
    @ObservedObject var monitor: InputMonitor
    var compact: () -> Void
    var restart: () -> Void
    @State private var tab = "概览"
    init(store: StatisticsStore, monitor: InputMonitor, compact: @escaping () -> Void, initialTab: String = "概览", restart: @escaping () -> Void = {}) {
        self.store = store; self.monitor = monitor; self.compact = compact; self.restart = restart
        _tab = State(initialValue: initialTab)
    }
    private let tabs = [("概览", "square.grid.2x2"), ("键盘热力", "keyboard"), ("词语画像", "text.bubble"), ("设置与隐私", "slider.horizontal.3")]

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if let error = store.storageError {
                            Text(error).font(.system(size: 12)).foregroundColor(.orange).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.08)).cornerRadius(10)
                        }
                        if !monitor.listening && tab != "设置与隐私" { permissionBanner }
                        switch tab {
                        case "键盘热力": keyboardPage
                        case "词语画像": wordsPage
                        case "设置与隐私": SettingsView(store: store, monitor: monitor, restart: restart)
                        default: overview
                        }
                    }.padding(28)
                }
                HStack(spacing: 7) {
                    Image(systemName: "lock.shield").foregroundColor(Theme.mint)
                    Text("所有数据仅保存在这台 Mac 上")
                    Spacer()
                    Text("TRACE / 01").tracking(2)
                }.font(.system(size: 10)).foregroundColor(Theme.muted).padding(.horizontal, 28).padding(.vertical, 13)
            }
        }
        .background(Theme.background).foregroundColor(Theme.text)
        .preferredColorScheme(appearanceTheme.colorScheme)
        .frame(minWidth: 940, minHeight: 680)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                TraceMark()
                VStack(alignment: .leading, spacing: 2) {
                    Text("迹").font(.system(size: 22, weight: .semibold))
                    Text("T R A C E").font(.system(size: 9, weight: .medium)).foregroundColor(Theme.muted)
                }
            }.padding(.top, 42).padding(.bottom, 42).padding(.leading, 24)
            Text("你的数字足迹").font(.system(size: 10)).foregroundColor(Theme.muted).padding(.leading, 24).padding(.bottom, 14)
            ForEach(tabs, id: \.0) { item in
                Button { tab = item.0 } label: {
                    HStack(spacing: 11) {
                        Image(systemName: item.1).font(.system(size: 14)).frame(width: 20)
                        Text(item.0).font(.system(size: 13, weight: tab == item.0 ? .semibold : .regular))
                        Spacer()
                        if tab == item.0 { Circle().fill(Theme.mint).frame(width: 5, height: 5) }
                    }.foregroundColor(tab == item.0 ? Theme.mint : Theme.muted)
                        .padding(.horizontal, 14).padding(.vertical, 13)
                        .background(tab == item.0 ? Theme.mint.opacity(0.08) : .clear).cornerRadius(10)
                }.buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 6)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle().fill(store.paused ? Color.orange : monitor.listening ? Theme.mint : Theme.muted).frame(width: 6, height: 6)
                    Text(store.paused ? "已暂停记录" : monitor.listening ? "正在记录足迹" : "等待授权").font(.system(size: 11))
                }
                Text("每一次移动，都有迹可循。").font(.system(size: 10)).foregroundColor(Theme.muted)
                Button(action: compact) { Label("切换悬浮窗", systemImage: "pip.enter").font(.system(size: 11)) }
                    .buttonStyle(.plain).foregroundColor(Theme.mint).padding(.top, 8)
            }.padding(24)
        }.frame(width: 184).background(Theme.sidebar)
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(tab == "概览" ? "今天，也在创造。" : tab).font(.system(size: 23, weight: .semibold))
                Text(Date(), format: .dateTime.year().month(.wide).day().weekday(.wide)).font(.system(size: 11)).foregroundColor(Theme.muted)
            }
            Spacer()
            if tab != "设置与隐私" {
                Picker("统计范围", selection: $store.selectedPeriod) {
                    Text("今天").tag(0); Text("累计").tag(1)
                }.pickerStyle(.segmented).frame(width: 116).labelsHidden()
            }
            Button { store.paused.toggle() } label: {
                Image(systemName: store.paused ? "play.fill" : "pause.fill").font(.system(size: 12)).frame(width: 32, height: 30)
            }.buttonStyle(.plain).background(Theme.card).cornerRadius(9).help(store.paused ? "继续统计" : "暂停所有统计")
        }.padding(.horizontal, 28).padding(.top, 32).padding(.bottom, 20)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised").foregroundColor(Theme.mint)
            VStack(alignment: .leading, spacing: 4) {
                Text(monitor.inputGranted ? "权限已开启，监听尚未启动" : "从一次授权开始").font(.system(size: 13, weight: .semibold))
                Text(monitor.inputGranted ? "请退出后重新打开 Trace，或在设置中重试。" : "开启「输入监控」，开始记录鼠标距离和按键次数。").font(.system(size: 11)).foregroundColor(Theme.muted)
            }
            Spacer()
            Button("前往设置") { tab = "设置与隐私" }.buttonStyle(.bordered).tint(Theme.mint)
        }.padding(16).background(Theme.mint.opacity(0.06)).cornerRadius(14)
    }
    private var overview: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                metricCard(title: "鼠标行走距离", icon: "cursorarrow.motionlines", value: distanceParts(store.displayed.distanceMeters).0, unit: distanceParts(store.displayed.distanceMeters).1, color: Theme.mint, footnote: "屏幕上的每一小步", isMouse: true)
                metricCard(title: "键盘敲击次数", icon: "keyboard", value: number(store.displayed.totalKeys), unit: "次", color: Theme.blue, footnote: "灵感从指尖出发", isMouse: false)
            }
            VStack(alignment: .leading, spacing: 20) {
                SectionLabel(title: "活跃时刻", subtitle: store.selectedPeriod == 0 ? "今日 · 按小时统计" : "累计 · 各小时汇总")
                HourlyChart(values: store.displayed.hourlyKeys)
            }.cardStyle()
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel(title: "指尖偏好", subtitle: "TOP 5")
                    let keys = store.displayed.keyCounts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(5)
                    if keys.isEmpty {
                        EmptyState(icon: "keyboard", title: "等待第一下敲击", detail: "开始使用键盘，发现你的常用按键。")
                    } else {
                        ForEach(Array(keys), id: \.key) { item in keyBar(item.key, count: item.value, max: keys.first?.value ?? 1) }
                    }
                }.frame(maxWidth: .infinity, alignment: .topLeading).cardStyle()
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel(title: "最近在表达什么", subtitle: "词语画像")
                    if !store.wordTrackingEnabled {
                        EmptyState(icon: "text.bubble", title: "让文字留下轮廓", detail: "可在设置中开启本地词频分析。\n只保存词频，不保存输入原文。")
                    } else if store.displayed.words.isEmpty {
                        EmptyState(icon: "sparkle", title: "画像正在慢慢形成", detail: monitor.textStatus)
                    } else { wordCloud(limit: 10) }
                }.frame(maxWidth: .infinity, alignment: .topLeading).cardStyle()
            }
            Text("鼠标距离为屏幕光标轨迹的估算值；按键次数不含长按产生的自动重复。").font(.system(size: 10)).foregroundColor(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func metricCard(title: String, icon: String, value: String, unit: String, color: Color, footnote: String, isMouse: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(title).font(.system(size: 12)).foregroundColor(Theme.muted)
                Spacer()
                Image(systemName: icon).foregroundColor(color).font(.system(size: 19))
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value).font(.system(size: 44, weight: .medium, design: .rounded)).tracking(-1.5).minimumScaleFactor(0.5).lineLimit(1)
                Text(unit).font(.system(size: 15)).foregroundColor(Theme.muted)
            }
            HStack {
                Text(footnote).font(.system(size: 10)).foregroundColor(Theme.muted)
                Spacer()
                Image(systemName: isMouse ? "point.topleft.down.curvedto.point.bottomright.up" : "waveform.path").foregroundColor(color.opacity(0.6))
            }
        }.frame(height: 130).frame(maxWidth: .infinity).cardStyle()
    }
    private func keyBar(_ key: String, count: Int, max: Int) -> some View {
        HStack(spacing: 12) {
            Text(key).font(.system(size: 10, weight: .medium, design: .monospaced)).frame(width: 52, height: 25).background(Theme.quietFill).cornerRadius(6)
            GeometryReader { geometry in
                Capsule().fill(Theme.blue.opacity(0.13)).overlay(alignment: .leading) {
                    Capsule().fill(Theme.blue.opacity(0.8)).frame(width: maxWidth(geometry.size.width, count, max))
                }
            }.frame(height: 5)
            Text(number(count)).font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.muted).frame(minWidth: 30, alignment: .trailing)
        }
    }
    private func maxWidth(_ width: CGFloat, _ count: Int, _ maximum: Int) -> CGFloat { width * CGFloat(count) / CGFloat(max(1, maximum)) }
    private var keyboardPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(number(store.displayed.totalKeys)).font(.system(size: 42, weight: .medium, design: .rounded))
                Text("次敲击").foregroundColor(Theme.muted)
                Spacer()
                Text("\(store.displayed.keyCounts.count) 个按键被使用").font(.system(size: 12)).foregroundColor(Theme.muted)
            }
            VStack(alignment: .leading, spacing: 22) {
                SectionLabel(title: "键盘热力图", subtitle: appearanceTheme == .light ? "颜色越深，使用越频繁" : "颜色越亮，使用越频繁")
                KeyboardHeatmap(counts: store.displayed.keyCounts)
                HStack(spacing: 5) {
                    Text("少").padding(.trailing, 3)
                    ForEach(0..<6) { i in RoundedRectangle(cornerRadius: 3).fill(Theme.mint.opacity(0.05 + Double(i) * 0.16)).frame(width: 17, height: 9) }
                    Text("多").padding(.leading, 3)
                    Spacer()
                    Text("悬停查看次数 · ANSI 布局示意")
                }.font(.system(size: 10)).foregroundColor(Theme.muted)
            }.cardStyle()
            VStack(alignment: .leading, spacing: 18) {
                SectionLabel(title: "按键使用排行", subtitle: "全部已记录按键")
                let sorted = store.displayed.keyCounts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
                if sorted.isEmpty { EmptyState(icon: "keyboard", title: "还没有按键记录", detail: "授予输入监控权限后，正常使用键盘即可。") }
                ForEach(sorted, id: \.key) { item in keyBar(item.key, count: item.value, max: sorted.first?.value ?? 1) }
            }.cardStyle()
        }
    }
    private var wordsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "text.bubble").font(.system(size: 26)).foregroundColor(Theme.lilac)
                VStack(alignment: .leading, spacing: 6) {
                    Text("文字里，藏着你的关注。 ").font(.system(size: 18, weight: .medium))
                    Text("中英文分词 · 本地分析 · 自动过滤常见虚词").font(.system(size: 11)).foregroundColor(Theme.muted)
                }
                Spacer()
            }.padding(.bottom, 6)
            HStack(spacing: 16) {
                wordStat("已识别字符", number(store.displayed.characterCount))
                wordStat("不同词语", number(store.displayed.words.count))
                wordStat("词语出现次数", number(store.displayed.words.values.reduce(0, +)))
            }
            VStack(alignment: .leading, spacing: 24) {
                SectionLabel(title: "你的词语星图", subtitle: "TOP 40")
                if store.displayed.words.isEmpty {
                    EmptyState(icon: "sparkles", title: store.wordTrackingEnabled ? "等待文字，浮现轮廓" : "词语画像尚未开启", detail: store.wordTrackingEnabled ? monitor.textStatus : "前往「设置与隐私」开启，并授予辅助功能权限。")
                } else { wordCloud(limit: 40).padding(.vertical, 10) }
            }.cardStyle()
            Text("词频来自支持辅助功能的输入框，仅分析开启后新增的文本。输入法、自动补全和应用支持情况可能影响结果；编辑撤回会修正当前输入框的统计。不会保存原文或按时间回放输入内容。").font(.system(size: 11)).foregroundColor(Theme.muted).lineSpacing(5)
        }
    }
    private func wordStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 11)).foregroundColor(Theme.muted)
            Text(value).font(.system(size: 26, weight: .medium, design: .rounded)).foregroundColor(Theme.lilac)
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle()
    }
    private func wordCloud(limit: Int) -> some View {
        let words = Array(store.displayed.words.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(limit))
        let maximum = words.first?.value ?? 1
        return WordFlow(spacing: 9) {
            ForEach(words, id: \.key) { word in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(word.key).font(.system(size: 12 + 10 * CGFloat(word.value) / CGFloat(maximum), weight: .medium))
                    Text("\(word.value)").font(.system(size: 9, design: .monospaced)).opacity(0.55)
                }.foregroundColor(Theme.lilac).padding(.horizontal, 13).padding(.vertical, 9).background(Theme.lilac.opacity(0.07)).cornerRadius(9)
            }
        }
    }
}

struct HourlyChart: View {
    var values: [Int]
    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                let maximum = max(1, values.max() ?? 1)
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<24) { hour in
                        let value = hour < values.count ? values[hour] : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(value > 0 ? Theme.mint.opacity(hour == Calendar.current.component(.hour, from: Date()) ? 1 : 0.55) : Theme.quietFill)
                            .frame(height: max(3, (geometry.size.height - 4) * CGFloat(value) / CGFloat(maximum)))
                            .help(String(format: "%02d:00 · %@ 次", hour, number(value)))
                    }
                }.frame(maxHeight: .infinity, alignment: .bottom)
            }.frame(height: 78)
            HStack { ForEach(["00:00", "06:00", "12:00", "18:00", "23:00"], id: \.self) { label in Text(label); if label != "23:00" { Spacer() } } }
                .font(.system(size: 9, design: .monospaced)).foregroundColor(Theme.muted)
        }
    }
}

struct KeyboardHeatmap: View {
    let counts: [String: Int]
    private let rows = [
        ["Esc", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"],
        ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "−", "=", "Delete"],
        ["Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\"],
        ["Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "Return"],
        ["⇧", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "R⇧"],
        ["Fn", "⌃", "⌥", "⌘", "Space", "R⌘", "R⌥", "←", "↑", "↓", "→"]
    ]
    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 5) {
                    ForEach(rows[index], id: \.self) { key in
                        let value = counts[key, default: 0]
                        let intensity = value == 0 ? 0 : 0.15 + 0.8 * log(Double(value) + 1) / log(Double(max(1, counts.values.max() ?? 1)) + 1)
                        Text(key).font(.system(size: key.count > 3 ? 8 : 10, weight: .medium, design: .monospaced))
                            .frame(maxWidth: .infinity).frame(height: 32)
                            .frame(minWidth: key == "Space" ? 150 : key == "Return" ? 54 : 0)
                            .foregroundColor(intensity > 0.45 ? Theme.heatmapLabel : Theme.muted)
                            .background(value == 0 ? Theme.quietFill : Theme.mint.opacity(intensity))
                            .cornerRadius(5).overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.line, lineWidth: 1))
                            .help("\(key) · \(number(value)) 次")
                    }
                }
            }
        }
    }
}
