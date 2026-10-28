using System.Globalization;
using System.Text;

namespace Trace.Core;

public sealed class DayStatistics
{
    public double DistanceMeters { get; set; }
    public Dictionary<string, long> KeyCounts { get; set; } = [];
    public Dictionary<string, long> Words { get; set; } = [];
    public long CharacterCount { get; set; }
    public long[] HourlyKeys { get; set; } = new long[24];
    [System.Text.Json.Serialization.JsonIgnore]
    public long TotalKeys => KeyCounts.Values.Sum();
}

public sealed class SavedStatistics
{
    public int Version { get; set; } = 1;
    public Dictionary<string, DayStatistics> Days { get; set; } = [];
    public bool WordTrackingEnabled { get; set; }
    public List<string> ExcludedExecutables { get; set; } =
    ["1password.exe", "bitwarden.exe", "keepass.exe", "keepassxc.exe", "credentialuibroker.exe",
     "cmd.exe", "powershell.exe", "pwsh.exe", "windowsterminal.exe", "conhost.exe", "wezterm-gui.exe", "mintty.exe"];
    public static string DayKey(DateTime date) => date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
}

public sealed class Preferences
{
    public string Theme { get; set; } = "light";
    public bool Compact { get; set; }
    public double? FloatingLeft { get; set; }
    public double? FloatingTop { get; set; }
}

public readonly record struct PointD(double X, double Y);
public readonly record struct ScreenGeometry(double Left, double Top, double Width, double Height, double WidthMillimeters, double HeightMillimeters)
{
    public bool Contains(PointD p) => p.X >= Left && p.Y >= Top && p.X < Left + Width && p.Y < Top + Height;
    public double Distance(PointD from, PointD to)
    {
        if (Width <= 0 || Height <= 0 || !Contains(from) || !Contains(to)) return 0;
        var widthMm = WidthMillimeters > 0 ? WidthMillimeters : Width * 25.4 / 96;
        var heightMm = HeightMillimeters > 0 ? HeightMillimeters : Height * 25.4 / 96;
        var dx = (to.X - from.X) * widthMm / Width;
        var dy = (to.Y - from.Y) * heightMm / Height;
        return Math.Sqrt(dx * dx + dy * dy) / 1000;
    }
}

// Physical key identities include scan code and extended bit. Auto-repeat never increments the count.
public sealed class KeyStateTracker
{
    private readonly HashSet<int> down = [];
    public bool Press(int identity) => down.Add(identity);
    public void Release(int identity) => down.Remove(identity);
    public void Reset() => down.Clear();
}

public sealed class TextDraft
{
    private string[] text;
    private readonly List<bool> authored;
    public TextDraft(string baseline)
    {
        text = Elements(baseline);
        authored = Enumerable.Repeat(false, text.Length).ToList();
    }
    public void Update(string current)
    {
        var next = Elements(current);
        var prefix = 0;
        while (prefix < Math.Min(text.Length, next.Length) && text[prefix] == next[prefix]) prefix++;
        var suffix = 0;
        while (suffix < Math.Min(text.Length, next.Length) - prefix && text[^(suffix + 1)] == next[^(suffix + 1)]) suffix++;
        authored.RemoveRange(prefix, text.Length - prefix - suffix);
        authored.InsertRange(prefix, Enumerable.Repeat(true, next.Length - prefix - suffix));
        text = next;
    }
    public string InsertedText => string.Concat(text.Select((value, i) => authored[i] ? value : " "));
    public static string[] Elements(string value)
    {
        var result = new List<string>();
        var iterator = StringInfo.GetTextElementEnumerator(value);
        while (iterator.MoveNext()) result.Add(iterator.GetTextElement());
        return result.ToArray();
    }
}

public static class WordAnalysis
{
    private static readonly HashSet<string> Ignored = new(StringComparer.OrdinalIgnoreCase)
    { "the", "and", "for", "that", "this", "with", "are", "you", "your", "from", "have", "was", "but", "not",
      "一个", "这个", "那个", "我们", "你们", "他们", "自己", "可以", "什么", "就是", "因为", "所以", "已经", "没有", "还是", "以及" };
    public static Dictionary<string, long> Count(IEnumerable<string> segments)
    {
        var counts = new Dictionary<string, long>();
        foreach (var segment in segments)
        {
            var word = segment.ToLowerInvariant();
            var length = StringInfo.ParseCombiningCharacters(word).Length;
            if (length < 2 || length > 24 || Ignored.Contains(word) || !word.EnumerateRunes().All(Rune.IsLetter)) continue;
            counts[word] = counts.GetValueOrDefault(word) + 1;
        }
        return counts;
    }
    public static int CharacterCount(string text) => TextDraft.Elements(text).Count(x => !string.IsNullOrWhiteSpace(x));
}
