import Foundation
import AppKit

func XCTAssertTrue(_ value: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    precondition(value(), "Expected true", file: file, line: line)
}
func XCTAssertFalse(_ value: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    precondition(!value(), "Expected false", file: file, line: line)
}
func XCTAssertNotNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) {
    precondition(value != nil, "Expected non-nil", file: file, line: line)
}
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) {
    precondition(a == b, "Expected \(a) == \(b)", file: file, line: line)
}
func XCTAssertEqual(_ a: Double, _ b: Double, accuracy: Double, file: StaticString = #file, line: UInt = #line) {
    precondition(abs(a - b) <= accuracy, "Expected \(a) ≈ \(b)", file: file, line: line)
}

@main
struct CoreChecks {
    static func main() throws {
        let checks = CoreChecks()
        checks.testDistanceUsesLogicalScreenPointsAndPhysicalSize()
        checks.testDistanceHandlesDifferentHorizontalAndVerticalScale()
        checks.testMissingPhysicalSizeUsesFallback()
        checks.testOnlyNewlyAuthoredTextEntersProfile()
        checks.testIMEReplacementRevisesDraft()
        checks.testMiddleInsertionAndDeletionPreserveAttribution()
        checks.testEmojiAndGraphemeEditsDoNotBreakAttribution()
        checks.testProfileRejectsNumbersPunctuationAndCommonStopWords()
        try checks.testDailyRollupPausePersistenceAndRevision()
        try checks.testCorruptStorageIsPreserved()
        print("PASS — 10 core checks: distance, typing attribution, IME, segmentation, persistence, corruption protection")
    }

    func testDistanceUsesLogicalScreenPointsAndPhysicalSize() {
        let screen = ScreenGeometry(bounds: CGRect(x: 0, y: 0, width: 1440, height: 900), millimeters: CGSize(width: 288, height: 180))
        XCTAssertEqual(screen.distance(from: .zero, to: CGPoint(x: 300, y: 400)), 0.1, accuracy: 0.000001)
    }
    func testDistanceHandlesDifferentHorizontalAndVerticalScale() {
        let screen = ScreenGeometry(bounds: CGRect(x: -1920, y: 0, width: 1920, height: 1080), millimeters: CGSize(width: 480, height: 300))
        XCTAssertEqual(screen.distance(from: CGPoint(x: -1000, y: 0), to: CGPoint(x: -1000, y: 1080)), 0.3, accuracy: 0.000001)
    }
    func testMissingPhysicalSizeUsesFallback() {
        let screen = ScreenGeometry(bounds: CGRect(x: 0, y: 0, width: 1100, height: 1100), millimeters: .zero)
        XCTAssertEqual(screen.distance(from: .zero, to: CGPoint(x: 1100, y: 0)), 0.254, accuracy: 0.000001)
    }
    func testOnlyNewlyAuthoredTextEntersProfile() {
        var draft = TextDraft(baseline: "原有的私密文字")
        XCTAssertTrue(TextAnalysis.words(in: draft.insertedText).isEmpty)
        draft.update("原有的私密文字 hello world")
        XCTAssertEqual(TextAnalysis.words(in: draft.insertedText), ["hello", "world"])
        XCTAssertFalse(draft.insertedText.contains("私密"))
    }
    func testIMEReplacementRevisesDraft() {
        var draft = TextDraft(baseline: "")
        draft.update("kaifa")
        draft.update("开发")
        XCTAssertEqual(draft.insertedText, "开发")
        XCTAssertEqual(TextAnalysis.words(in: draft.insertedText), ["开发"])
    }
    func testMiddleInsertionAndDeletionPreserveAttribution() {
        var draft = TextDraft(baseline: "hello world")
        draft.update("hello beautiful world")
        XCTAssertEqual(TextAnalysis.words(in: draft.insertedText), ["beautiful"])
        draft.update("hello world")
        XCTAssertTrue(TextAnalysis.words(in: draft.insertedText).isEmpty)
    }
    func testEmojiAndGraphemeEditsDoNotBreakAttribution() {
        var draft = TextDraft(baseline: "👩🏽‍💻")
        draft.update("👩🏽‍💻 编程")
        XCTAssertEqual(TextAnalysis.words(in: draft.insertedText), ["编程"])
    }
    func testProfileRejectsNumbersPunctuationAndCommonStopWords() {
        let words = TextAnalysis.words(in: "the TRACE trace 12345 hello@example.com 一个 我们 软件 开发")
        XCTAssertFalse(words.contains("the"))
        XCTAssertFalse(words.contains("12345"))
        XCTAssertFalse(words.contains("我们"))
        XCTAssertEqual(words.filter { $0 == "trace" }.count, 2)
        XCTAssertTrue(words.contains("软件"))
    }
    func testDailyRollupPausePersistenceAndRevision() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = StatisticsStore(directory: root)
        var calendar = Calendar.current
        calendar.timeZone = .current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        store.record(distance: 1.25, key: "A", at: yesterday)
        store.record(distance: 2, key: "B")
        store.paused = true
        store.record(distance: 10, key: "C")
        XCTAssertEqual(store.today.totalKeys, 1)
        store.paused = false
        store.setWordTracking(true)
        store.reviseWords(from: [:], to: ["hello": 1], characterDelta: 5)
        store.reviseWords(from: ["hello": 1], to: ["hello": 1, "world": 1], characterDelta: 5)
        XCTAssertEqual(store.today.words, ["hello": 1, "world": 1])
        store.reviseWords(from: ["hello": 1, "world": 1], to: ["hello": 1], characterDelta: -5)
        XCTAssertEqual(store.today.words, ["hello": 1])
        XCTAssertEqual(store.today.characterCount, 5)
        store.selectedPeriod = 1
        XCTAssertEqual(store.displayed.distanceMeters, 3.25)
        XCTAssertEqual(store.displayed.totalKeys, 2)
        store.save()
        let loaded = StatisticsStore(directory: root)
        XCTAssertEqual(loaded.data.days, store.data.days)
        let json = try String(contentsOf: store.fileURL, encoding: .utf8)
        XCTAssertFalse(json.contains("insertedText"))
        XCTAssertFalse(json.contains("baseline"))
        store.clearWords()
        XCTAssertEqual(store.displayed.totalKeys, 2)
        XCTAssertTrue(store.displayed.words.isEmpty)
        store.clearAll()
        XCTAssertEqual(store.displayed.totalKeys, 0)
    }
    func testCorruptStorageIsPreserved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("statistics.json")
        try Data("corrupt original".utf8).write(to: url)
        let store = StatisticsStore(directory: root)
        XCTAssertNotNil(store.storageError)
        store.record(key: "A"); store.save()
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "corrupt original")
    }
}
