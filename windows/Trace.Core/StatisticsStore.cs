using System.Text.Json;

namespace Trace.Core;

// Called only on the UI thread. A background accessibility sampler returns aggregate deltas.
public sealed class StatisticsStore
{
    public static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, WriteIndented = true };
    public SavedStatistics Data { get; private set; } = new();
    public Preferences Preferences { get; private set; } = new();
    public bool Paused { get; set; }
    public string? StorageError { get; private set; }
    public string DirectoryPath { get; }
    public string FilePath => Path.Combine(DirectoryPath, "statistics.json");
    public int Revision { get; private set; }
    public int TextGeneration { get; private set; }
    private bool dirty;
    private bool preferencesReadable = true;
    public StatisticsStore(string? directory = null)
    {
        DirectoryPath = directory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Trace");
        try
        {
            Directory.CreateDirectory(DirectoryPath);
            if (File.Exists(FilePath))
            {
                var loaded = JsonSerializer.Deserialize<SavedStatistics>(File.ReadAllText(FilePath), JsonOptions);
                if (loaded is null || loaded.Version != 1 || loaded.Days is null || loaded.ExcludedExecutables is null ||
                    loaded.Days.Any(x => x.Value is null || x.Value.KeyCounts is null || x.Value.Words is null || x.Value.HourlyKeys is null ||
                        !double.IsFinite(x.Value.DistanceMeters) || x.Value.DistanceMeters < 0 || x.Value.CharacterCount < 0 ||
                        x.Value.KeyCounts.Values.Any(n => n < 0) || x.Value.Words.Values.Any(n => n < 0) || x.Value.HourlyKeys.Any(n => n < 0)))
                    throw new InvalidDataException("不支持或损坏的统计格式");
                Data = loaded;
            }
        }
        catch (Exception error) { StorageError = "统计读取失败，原文件已保留：" + error.Message; }
        try
        {
            var file = Path.Combine(DirectoryPath, "preferences.json");
            if (File.Exists(file)) Preferences = JsonSerializer.Deserialize<Preferences>(File.ReadAllText(file), JsonOptions) ?? new();
            if (Preferences.Theme is not ("light" or "dark")) Preferences.Theme = "light";
        }
        catch { preferencesReadable = false; } // Do not overwrite an unreadable preference file.
    }
    public DayStatistics Today(DateTime? at = null) => Data.Days.GetValueOrDefault(SavedStatistics.DayKey(at ?? DateTime.Now)) ?? new();
    public DayStatistics Displayed(bool cumulative)
    {
        if (!cumulative) return Today();
        var result = new DayStatistics();
        foreach (var day in Data.Days.Values)
        {
            result.DistanceMeters += day.DistanceMeters;
            result.CharacterCount += day.CharacterCount;
            foreach (var (key, count) in day.KeyCounts) result.KeyCounts[key] = result.KeyCounts.GetValueOrDefault(key) + count;
            foreach (var (word, count) in day.Words) result.Words[word] = result.Words.GetValueOrDefault(word) + count;
            for (var h = 0; h < Math.Min(24, day.HourlyKeys.Length); h++) result.HourlyKeys[h] += day.HourlyKeys[h];
        }
        return result;
    }
    private DayStatistics Day(DateTime at)
    {
        var dayKey = SavedStatistics.DayKey(at);
        if (!Data.Days.TryGetValue(dayKey, out var day)) Data.Days[dayKey] = day = new();
        if (day.HourlyKeys.Length != 24) day.HourlyKeys = new long[24];
        return day;
    }
    public void RecordDistance(double meters, DateTime? at = null)
    {
        if (Paused || !double.IsFinite(meters) || meters <= 0) return;
        Day(at ?? DateTime.Now).DistanceMeters += meters; Changed();
    }
    public void RecordKey(string key, DateTime? at = null)
    {
        if (Paused) return;
        var date = at ?? DateTime.Now;
        var day = Day(date);
        day.KeyCounts[key] = day.KeyCounts.GetValueOrDefault(key) + 1;
        day.HourlyKeys[date.Hour]++;
        Changed();
    }
    public bool IsExcluded(string executable) => Data.ExcludedExecutables.Contains(executable, StringComparer.OrdinalIgnoreCase);
    public void AddExcluded(string executable)
    {
        executable = executable.Trim().ToLowerInvariant();
        if (executable.Length == 0 || executable.IndexOfAny(['/', '\\', ':', '*', '?']) >= 0 || !executable.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("请输入进程文件名，例如 chrome.exe");
        if (!IsExcluded(executable)) { Data.ExcludedExecutables.Add(executable); InvalidateText(); Changed(); }
    }
    public void RemoveExcluded(string executable)
    {
        Data.ExcludedExecutables.RemoveAll(x => string.Equals(x, executable, StringComparison.OrdinalIgnoreCase));
        InvalidateText(); Changed();
    }
    public void SetWordTracking(bool enabled)
    {
        Data.WordTrackingEnabled = enabled; InvalidateText(); Changed(); Save();
    }
    public void InvalidateText() => TextGeneration++;
    public void ReviseWords(string dayKey, IReadOnlyDictionary<string, long> oldWords, IReadOnlyDictionary<string, long> newWords, int characterDelta, int generation)
    {
        if (Paused || !Data.WordTrackingEnabled || generation != TextGeneration || dayKey != SavedStatistics.DayKey(DateTime.Now)) return;
        var day = Day(DateTime.Now);
        foreach (var word in oldWords.Keys.Union(newWords.Keys))
        {
            var count = Math.Max(0, day.Words.GetValueOrDefault(word) + newWords.GetValueOrDefault(word) - oldWords.GetValueOrDefault(word));
            if (count > 0) day.Words[word] = count; else day.Words.Remove(word);
        }
        day.CharacterCount = Math.Max(0, day.CharacterCount + characterDelta);
        if (day.Words.Count > 5000) day.Words = day.Words.OrderByDescending(x => x.Value).Take(4000).ToDictionary(x => x.Key, x => x.Value);
        Changed();
    }
    public void ClearWords()
    {
        InvalidateText();
        foreach (var day in Data.Days.Values) { day.Words.Clear(); day.CharacterCount = 0; }
        Changed(); Save();
    }
    public void ClearAll() { InvalidateText(); Data.Days.Clear(); Changed(); Save(); }
    private void Changed() { dirty = true; Revision++; }
    public void Save()
    {
        if (!dirty || StorageError is not null) return;
        try { AtomicWrite(FilePath, JsonSerializer.Serialize(Data, JsonOptions)); dirty = false; }
        catch (Exception error) { StorageError = "统计保存失败：" + error.Message; }
    }
    public void SavePreferences()
    {
        if (!preferencesReadable) return;
        try { AtomicWrite(Path.Combine(DirectoryPath, "preferences.json"), JsonSerializer.Serialize(Preferences, JsonOptions)); }
        catch (Exception error) { StorageError ??= "偏好保存失败：" + error.Message; }
    }
    public void BackupAndRetry()
    {
        try
        {
            if (File.Exists(FilePath)) File.Copy(FilePath, Path.Combine(DirectoryPath, "statistics-backup-" + Guid.NewGuid() + ".json"));
            StorageError = null; dirty = true; Save();
        }
        catch (Exception error) { StorageError = "备份失败，原文件未覆盖：" + error.Message; }
    }
    public void Export(string path) => AtomicWrite(path, JsonSerializer.Serialize(Data, JsonOptions));
    private static void AtomicWrite(string path, string content)
    {
        var temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var writer = new StreamWriter(new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None)))
            { writer.Write(content); writer.Flush(); ((FileStream)writer.BaseStream).Flush(true); }
            File.Move(temporary, path, overwrite: true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
