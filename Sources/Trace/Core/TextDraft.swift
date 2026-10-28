import Foundation

/// Tracks only characters inserted after observing a field, allowing IME replacements
/// and edits to revise the current contribution without storing the original field.
struct TextDraft {
    private(set) var text: String
    private var authored: [Bool]
    init(baseline: String) { text = baseline; authored = Array(repeating: false, count: baseline.count) }
    mutating func update(_ next: String) {
        let old = Array(text), new = Array(next)
        var prefix = 0
        while prefix < min(old.count, new.count), old[prefix] == new[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(old.count, new.count) - prefix,
              old[old.count - suffix - 1] == new[new.count - suffix - 1] { suffix += 1 }
        authored.replaceSubrange(prefix..<(old.count - suffix), with: repeatElement(true, count: new.count - prefix - suffix))
        text = next
    }
    var insertedText: String {
        zip(Array(text), authored).map { $0.1 ? String($0.0) : " " }.joined()
    }
}
