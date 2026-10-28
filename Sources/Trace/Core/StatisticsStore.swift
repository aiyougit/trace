import AppKit
import Combine

final class StatisticsStore: ObservableObject {
    @Published private(set) var data: SavedStatistics
    @Published var paused = false
    @Published var selectedPeriod = 0
    @Published var storageError: String?
    private var dirty = false
    private var saveTimer: Timer?
    let fileURL: URL

    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Trace", isDirectory: true)
        fileURL = root.appendingPathComponent("statistics.json")
        data = SavedStatistics()
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                data = try JSONDecoder().decode(SavedStatistics.self, from: Data(contentsOf: fileURL))
            }
        } catch { storageError = "本地统计读取失败，原文件已保留：\(error.localizedDescription)" }
        saveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.save() }
    }

    deinit { saveTimer?.invalidate() }

    var today: DayStatistics { data.days[SavedStatistics.dayKey()] ?? DayStatistics() }
    var displayed: DayStatistics {
        if selectedPeriod == 0 { return today }
        return data.days.values.reduce(into: DayStatistics()) { result, day in
            result.distanceMeters += day.distanceMeters
            result.characterCount += day.characterCount
            day.keyCounts.forEach { result.keyCounts[$0.key, default: 0] += $0.value }
            day.words.forEach { result.words[$0.key, default: 0] += $0.value }
            for i in 0..<min(24, day.hourlyKeys.count) { result.hourlyKeys[i] += day.hourlyKeys[i] }
        }
    }
    var wordTrackingEnabled: Bool { data.wordTrackingEnabled }
    var excludedBundleIDs: [String] { data.excludedBundleIDs }
    func setWordTracking(_ enabled: Bool) { data.wordTrackingEnabled = enabled; dirty = true; save() }
    func addExcludedApp(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier, !data.excludedBundleIDs.contains(id) else { return }
        data.excludedBundleIDs.append(id)
        data.excludedAppNames[id] = app.localizedName ?? id
        dirty = true; save()
    }
    func addExcludedBundle(_ id: String, name: String) {
        guard !data.excludedBundleIDs.contains(id) else { return }
        data.excludedBundleIDs.append(id); data.excludedAppNames[id] = name
        dirty = true; save()
    }
    func removeExcludedApp(_ id: String) { data.excludedBundleIDs.removeAll { $0 == id }; data.excludedAppNames[id] = nil; dirty = true; save() }
    func record(distance: Double = 0, key: String? = nil, text: String? = nil, at date: Date = Date()) {
        guard !paused else { return }
        let day = SavedStatistics.dayKey(date)
        var stats = data.days[day] ?? DayStatistics()
        stats.distanceMeters += max(0, distance)
        if let key {
            stats.keyCounts[key, default: 0] += 1
            let hour = Calendar.current.component(.hour, from: date)
            if stats.hourlyKeys.count != 24 { stats.hourlyKeys = Array(repeating: 0, count: 24) }
            stats.hourlyKeys[hour] += 1
        }
        if let text, wordTrackingEnabled {
            stats.characterCount += text.filter { !$0.isWhitespace }.count
            for word in TextAnalysis.words(in: text) { stats.words[word, default: 0] += 1 }
            // Bound local storage size; no original text is written to disk.
            if stats.words.count > 5000 { stats.words = Dictionary(uniqueKeysWithValues: stats.words.sorted { $0.value > $1.value }.prefix(4000).map { ($0.key, $0.value) }) }
        }
        data.days[day] = stats
        dirty = true
    }
    func reviseWords(from old: [String: Int], to new: [String: Int], characterDelta: Int) {
        guard !paused, wordTrackingEnabled else { return }
        let day = SavedStatistics.dayKey()
        var stats = data.days[day] ?? DayStatistics()
        for word in Set(old.keys).union(new.keys) {
            let count = max(0, stats.words[word, default: 0] + new[word, default: 0] - old[word, default: 0])
            if count > 0 { stats.words[word] = count } else { stats.words[word] = nil }
        }
        stats.characterCount = max(0, stats.characterCount + characterDelta)
        if stats.words.count > 5000 { stats.words = Dictionary(uniqueKeysWithValues: stats.words.sorted { $0.value > $1.value }.prefix(4000).map { ($0.key, $0.value) }) }
        data.days[day] = stats; dirty = true
    }
    func clearAll() {
        data.days = [:]; dirty = true; save()
    }
    func clearWords() {
        for day in Array(data.days.keys) { data.days[day]?.words = [:]; data.days[day]?.characterCount = 0 }
        dirty = true; save()
    }
    func save() {
        guard dirty else { return }
        // Do not overwrite a file that could not be decoded without explicit reset.
        guard storageError == nil else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(data).write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            dirty = false
        } catch { storageError = "统计保存失败：\(error.localizedDescription)" }
    }
    func resetStorageError() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let backup = fileURL.deletingLastPathComponent().appendingPathComponent("statistics-backup-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: fileURL, to: backup)
            }
            storageError = nil; dirty = true; save()
        } catch { storageError = "备份失败，原文件未覆盖：\(error.localizedDescription)" }
    }
}
