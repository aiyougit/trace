import Foundation
import NaturalLanguage

struct DayStatistics: Codable, Equatable {
    var distanceMeters: Double = 0
    var keyCounts: [String: Int] = [:]
    var words: [String: Int] = [:]
    var characterCount: Int = 0
    var hourlyKeys: [Int] = Array(repeating: 0, count: 24)
    var totalKeys: Int { keyCounts.values.reduce(0, +) }

}

struct SavedStatistics: Codable {
    var version = 1
    var days: [String: DayStatistics] = [:]
    var wordTrackingEnabled = false
    var excludedBundleIDs: [String] = [
        "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop",
        "com.apple.keychainaccess", "com.apple.Passwords", "org.keepassxc.keepassxc",
        "com.apple.Terminal", "com.googlecode.iterm2"
    ]
    var excludedAppNames: [String: String] = [:]
    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

struct ScreenGeometry {
    let bounds: CGRect
    let millimeters: CGSize
    func distance(from start: CGPoint, to end: CGPoint) -> Double {
        guard bounds.width > 0, bounds.height > 0 else { return 0 }
        // macOS reports cursor coordinates in display points, not Retina pixels.
        let widthMM = millimeters.width > 0 ? millimeters.width : bounds.width * 25.4 / 110
        let heightMM = millimeters.height > 0 ? millimeters.height : bounds.height * 25.4 / 110
        return hypot((end.x - start.x) * widthMM / bounds.width,
                     (end.y - start.y) * heightMM / bounds.height) / 1000
    }
}

enum TextAnalysis {
    static func insertion(previous: String, current: String) -> String {
        let a = Array(previous), b = Array(current)
        var prefix = 0
        while prefix < min(a.count, b.count), a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(a.count, b.count) - prefix,
              a[a.count - suffix - 1] == b[b.count - suffix - 1] { suffix += 1 }
        return String(b[prefix..<(b.count - suffix)])
    }

    static func words(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var result: [String] = []
        let ignored: Set<String> = ["the", "and", "for", "that", "this", "with", "are", "you", "your", "from", "have", "was", "but", "not", "一个", "这个", "那个", "我们", "你们", "他们", "自己", "可以", "什么", "就是", "因为", "所以", "已经", "没有", "还是", "以及"]
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).lowercased()
            if word.count >= 2, word.count <= 24,
               word.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }),
               !ignored.contains(word) { result.append(word) }
            return true
        }
        return result
    }
}

enum KeyNames {
    static let names: [Int64: String] = [
        0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",
        12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",
        22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",
        32:"U",33:"[",34:"I",35:"P",36:"Return",37:"L",38:"J",39:"'",40:"K",41:";",
        42:"\\",43:",",44:"/",45:"N",46:"M",47:".",48:"Tab",49:"Space",50:"`",
        51:"Delete",53:"Esc",54:"R⌘",55:"⌘",56:"⇧",57:"Caps",58:"⌥",59:"⌃",
        60:"R⇧",61:"R⌥",62:"R⌃",63:"Fn",64:"F17",65:"Num .",67:"Num *",69:"Num +",
        71:"Clear",75:"Num /",76:"Num Enter",78:"Num −",79:"F18",80:"F19",81:"Num =",
        82:"Num 0",83:"Num 1",84:"Num 2",85:"Num 3",86:"Num 4",87:"Num 5",88:"Num 6",
        89:"Num 7",90:"F20",91:"Num 8",92:"Num 9",96:"F5",97:"F6",98:"F7",99:"F3",
        100:"F8",101:"F9",103:"F11",105:"F13",106:"F16",107:"F14",109:"F10",111:"F12",
        113:"F15",114:"Help",115:"Home",116:"PgUp",117:"Del⌦",118:"F4",119:"End",
        120:"F2",121:"PgDn",122:"F1",123:"←",124:"→",125:"↓",126:"↑"
    ]
    static func name(for code: Int64) -> String { names[code] ?? "Key \(code)" }
}
