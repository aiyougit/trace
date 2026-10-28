using Trace.Core;

var checks = 0;
void Check(bool condition, string name) { if (!condition) throw new Exception("FAIL: " + name); checks++; Console.WriteLine("PASS: " + name); }
var geometry = new ScreenGeometry(0, 0, 3840, 2160, 600, 340);
Check(Math.Abs(geometry.Distance(new(0, 0), new(1920, 0)) - .3) < .000001, "physical pixels map to display millimeters, independent of UI scale");
Check(geometry.Distance(new(-1, 0), new(10, 0)) == 0, "cross-screen jump ignored");
var fallback = new ScreenGeometry(-1920, 0, 1920, 1080, 0, 0);
Check(Math.Abs(fallback.Distance(new(-1000, 1), new(-904, 1)) - .0254) < .000001, "96 PPI fallback and negative monitor origin");
var keys = new KeyStateTracker();
Check(keys.Press(30) && !keys.Press(30) && keys.Press(30 | 256), "key repeat ignored, extended key stays distinct");
keys.Release(30); Check(keys.Press(30), "keyup allows next physical press");
var draft = new TextDraft("已有文章"); draft.Update("已有文章ni"); draft.Update("已有文章你好");
Check(draft.InsertedText.Trim() == "你好", "IME replacement revises authored contribution");
draft.Update("已有文章你"); Check(draft.InsertedText.Trim() == "你", "deletion retracts contribution");
var unicode = new TextDraft("a👩‍💻b"); unicode.Update("a👩‍💻éb");
Check(unicode.InsertedText.Trim() == "é" && WordAnalysis.CharacterCount("👩‍💻 é") == 2, "grapheme-safe edit and character count");
var words = WordAnalysis.Count(["TRACE", "trace", "开发", "the", "123", "a", "hello@example.com"]);
Check(words.Count == 2 && words["trace"] == 2 && words["开发"] == 1, "segmentation filtering and normalization");
var root = Path.Combine(Path.GetTempPath(), "TraceChecks-" + Guid.NewGuid());
try
{
    var store = new StatisticsStore(root);
    var today = DateTime.Today;
    store.RecordKey("A", today.AddHours(9)); store.RecordKey("B", today.AddDays(-1).AddHours(12)); store.RecordDistance(2.5, today);
    Check(store.Displayed(true).TotalKeys == 2 && store.Today().HourlyKeys[9] == 1 && store.Today().DistanceMeters == 2.5, "daily, cumulative and hourly aggregation");
    store.Paused = true; store.RecordKey("A"); store.RecordDistance(9); store.Paused = false;
    Check(store.Displayed(true).TotalKeys == 2 && store.Today().DistanceMeters == 2.5, "pause stops all counters");
    store.AddExcluded("Custom.EXE"); Check(store.IsExcluded("custom.exe") && store.IsExcluded("pwsh.exe"), "case-insensitive process exclusions and secure defaults");
    store.SetWordTracking(true);
    var generation = store.TextGeneration;
    store.ReviseWords(SavedStatistics.DayKey(today), new Dictionary<string,long>(), words, 8, generation);
    store.ClearWords();
    store.ReviseWords(SavedStatistics.DayKey(today), new Dictionary<string,long>(), words, 8, generation);
    Check(store.Today().Words.Count == 0 && store.Today().CharacterCount == 0, "clear invalidates in-flight text samples");
    store.Save();
    var restored = new StatisticsStore(root);
    Check(restored.Today().TotalKeys == 1 && restored.Data.WordTrackingEnabled && restored.IsExcluded("CUSTOM.exe"), "aggregate persistence roundtrip");
    File.WriteAllText(store.FilePath, "broken original");
    var broken = new StatisticsStore(root); broken.RecordKey("X"); broken.Save();
    Check(broken.StorageError is not null && File.ReadAllText(store.FilePath) == "broken original", "corrupt file never overwritten silently");
    broken.BackupAndRetry();
    Check(broken.StorageError is null && Directory.GetFiles(root, "statistics-backup-*.json").Length == 1, "explicit recovery keeps original backup");
}
finally { if (Directory.Exists(root)) Directory.Delete(root, true); }
Console.WriteLine($"PASS — {checks} Windows core checks");
