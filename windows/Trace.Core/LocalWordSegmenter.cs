using System.Globalization;
using System.Text;

namespace Trace.Core;

/// <summary>Offline dictionary-frequency DAG segmentation with no Windows language-pack dependency.</summary>
public static class LocalWordSegmenter
{
    private sealed class Node
    {
        public readonly Dictionary<int, Node> Children = [];
        public long Frequency;
    }
    private sealed record DictionaryData(Node Root, double LogTotal);
    private static readonly Lazy<DictionaryData> Dictionary = new(LoadDictionary);
    private static DictionaryData LoadDictionary()
    {
        using var stream = typeof(LocalWordSegmenter).Assembly.GetManifestResourceStream("Trace.Core.ChineseDictionary")
            ?? throw new InvalidOperationException("本地中文词典未打包");
        using var reader = new StreamReader(stream, Encoding.UTF8);
        var root = new Node();
        double total = 0;
        while (reader.ReadLine() is { } line)
        {
            var fields = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (fields.Length < 2 || !long.TryParse(fields[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out var frequency) || frequency < 1) continue;
            var runes = fields[0].EnumerateRunes().ToArray();
            if (runes.Length == 0 || !runes.All(IsHan)) continue;
            var node = root;
            foreach (var rune in runes)
            {
                if (!node.Children.TryGetValue(rune.Value, out var next)) node.Children[rune.Value] = next = new();
                node = next;
            }
            node.Frequency = frequency; total += frequency;
        }
        if (total <= 0) throw new InvalidOperationException("本地中文词典为空");
        return new(root, Math.Log(total));
    }
    private static bool IsHan(Rune rune) => rune.Value is >= 0x3400 and <= 0x4DBF or >= 0x4E00 and <= 0x9FFF
        or >= 0xF900 and <= 0xFAFF or >= 0x20000 and <= 0x323AF;
    public static IEnumerable<string> Segment(string text)
    {
        var runes = text.EnumerateRunes().ToArray();
        var offset = 0;
        while (offset < runes.Length)
        {
            if (IsHan(runes[offset]))
            {
                var end = offset + 1;
                while (end < runes.Length && IsHan(runes[end])) end++;
                foreach (var word in SegmentHan(runes.AsSpan(offset, end - offset).ToArray())) yield return word;
                offset = end;
            }
            else if (Rune.IsLetter(runes[offset]))
            {
                var builder = new StringBuilder();
                do { builder.Append(runes[offset].ToString()); offset++; }
                while (offset < runes.Length && Rune.IsLetter(runes[offset]) && !IsHan(runes[offset]));
                yield return builder.ToString();
            }
            else offset++;
        }
    }
    private static IEnumerable<string> SegmentHan(Rune[] runes)
    {
        var dictionary = Dictionary.Value;
        var scores = new double[runes.Length + 1];
        var ends = new int[runes.Length];
        for (var i = runes.Length - 1; i >= 0; i--)
        {
            scores[i] = -dictionary.LogTotal + scores[i + 1]; ends[i] = i + 1;
            var node = dictionary.Root;
            for (var j = i; j < runes.Length; j++)
            {
                if (!node.Children.TryGetValue(runes[j].Value, out var next)) break;
                node = next;
                if (node.Frequency == 0) continue;
                var score = Math.Log(node.Frequency) - dictionary.LogTotal + scores[j + 1];
                if (score > scores[i]) { scores[i] = score; ends[i] = j + 1; }
            }
        }
        for (var i = 0; i < runes.Length;)
        {
            var builder = new StringBuilder();
            var end = ends[i];
            while (i < end) builder.Append(runes[i++].ToString());
            yield return builder.ToString();
        }
    }
    public static Dictionary<string, long> Count(string text) => WordAnalysis.Count(Segment(text));
}
