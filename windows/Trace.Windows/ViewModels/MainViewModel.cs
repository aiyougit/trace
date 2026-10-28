using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Runtime.CompilerServices;
using Trace.Core;
using Trace.Windows.Services;

namespace Trace.Windows.ViewModels;

internal sealed class HourBar : INotifyPropertyChanged
{
    public int Hour { get; init; }
    public double Height { get; private set; }
    public string Label => Hour % 6 == 0 ? Hour.ToString("00") : "";
    public string Tip { get; private set; } = "";
    public void Update(long count, long max)
    {
        Height = count == 0 ? 3 : Math.Max(6, 110.0 * count / Math.Max(1, max));
        Tip = $"{Hour:00}:00 · {count:N0} 次";
        PropertyChanged?.Invoke(this, new(nameof(Height))); PropertyChanged?.Invoke(this, new(nameof(Tip)));
    }
    public event PropertyChangedEventHandler? PropertyChanged;
}
internal sealed record RankingItem(string Name, long Count)
{
    public string CountText => Count.ToString("N0", CultureInfo.InvariantCulture);
    public double FontSize => 14 + Math.Min(22, Math.Log2(Count + 1) * 2);
}
internal sealed class MainViewModel : INotifyPropertyChanged
{
    internal StatisticsStore Store { get; }
    private readonly InputMonitor? monitor;
    private DayStatistics displayed = new();
    private int revision = -1;
    private string day = "";
    private bool cumulative;
    public bool Cumulative { get => cumulative; set { cumulative = value; Refresh(true); } }
    public ObservableCollection<HourBar> Hours { get; } = new(Enumerable.Range(0, 24).Select(h => new HourBar { Hour = h }));
    public ObservableCollection<RankingItem> Rankings { get; } = [];
    public ObservableCollection<RankingItem> TopKeys { get; } = [];
    public ObservableCollection<RankingItem> Words { get; } = [];
    public ObservableCollection<string> Excluded { get; } = [];
    public string DistanceText { get; private set; } = "0.00";
    public string DistanceUnit { get; private set; } = "m";
    public string KeyText { get; private set; } = "0";
    public string TodayDistance { get; private set; } = "0.00";
    public string TodayUnit { get; private set; } = "m";
    public string TodayKeys { get; private set; } = "0";
    public string CharacterText { get; private set; } = "0";
    public string WordCountText { get; private set; } = "0";
    public string Status => monitor?.Status ?? "演示数据 · 未启用监听";
    public string TextStatus => monitor?.TextStatus ?? "独立示例数据 · 无真实输入";
    public bool Paused => Store.Paused;
    public string PauseText => Store.Paused ? "继续统计" : "暂停统计";
    public string TodayLabel => DateTime.Now.ToString("yyyy年M月d日 dddd", CultureInfo.GetCultureInfo("zh-CN"));
    public string PeriodLabel => Cumulative ? "累计 · 按小时汇总" : "今日 · 按小时统计";
    public string WordEmptyText => Store.Data.WordTrackingEnabled ? "在支持的输入框中键入，稍后会出现中英文高频词。" : "在设置与隐私中开启词语画像；基础统计不需要开启此功能。";
    public string StoragePath => Store.FilePath;
    public string? StorageError => Store.StorageError;
    public bool HasStorageError => Store.StorageError is not null;
    public bool NoWords => Words.Count == 0;
    public bool NoKeys => Rankings.Count == 0;
    public bool WordTracking => Store.Data.WordTrackingEnabled;
    public event PropertyChangedEventHandler? PropertyChanged;
    internal event Action? SnapshotChanged;
    internal MainViewModel(StatisticsStore store, InputMonitor? monitor = null) { Store = store; this.monitor = monitor; Refresh(true); }
    public long KeyCount(string key) => displayed.KeyCounts.GetValueOrDefault(key);
    public long MaxKeyCount => displayed.KeyCounts.Count == 0 ? 0 : displayed.KeyCounts.Values.Max();
    public void Refresh(bool force = false)
    {
        var today = SavedStatistics.DayKey(DateTime.Now);
        if (force || revision != Store.Revision || day != today)
        {
            revision = Store.Revision; day = today; displayed = Store.Displayed(Cumulative);
            (DistanceText, DistanceUnit) = Distance(displayed.DistanceMeters);
            KeyText = Number(displayed.TotalKeys); CharacterText = Number(displayed.CharacterCount); WordCountText = Number(displayed.Words.Count);
            var actualToday = Store.Today();
            (TodayDistance, TodayUnit) = Distance(actualToday.DistanceMeters); TodayKeys = Number(actualToday.TotalKeys);
            Rankings.Clear(); TopKeys.Clear(); Words.Clear();
            foreach (var entry in displayed.KeyCounts.OrderByDescending(x => x.Value)) Rankings.Add(new(entry.Key, entry.Value));
            foreach (var entry in Rankings.Take(5)) TopKeys.Add(entry);
            foreach (var entry in displayed.Words.OrderByDescending(x => x.Value).Take(80)) Words.Add(new(entry.Key, entry.Value));
            var excluded = Store.Data.ExcludedExecutables.OrderBy(x => x).ToArray();
            if (!Excluded.SequenceEqual(excluded)) { Excluded.Clear(); foreach (var name in excluded) Excluded.Add(name); }
            var max = displayed.HourlyKeys.Length == 0 ? 0 : displayed.HourlyKeys.Max();
            for (var h = 0; h < 24; h++) Hours[h].Update(h < displayed.HourlyKeys.Length ? displayed.HourlyKeys[h] : 0, max);
            PropertyChanged?.Invoke(this, new("")); SnapshotChanged?.Invoke();
        }
        else
        {
            foreach (var name in new[] { nameof(Status), nameof(TextStatus), nameof(PauseText), nameof(StorageError), nameof(HasStorageError) })
                PropertyChanged?.Invoke(this, new(name));
        }
    }
    internal static string Number(long number) => number.ToString("N0", CultureInfo.InvariantCulture);
    internal static (string, string) Distance(double meters) => meters >= 1000 ? ((meters / 1000).ToString("F2", CultureInfo.InvariantCulture), "km") : (meters.ToString("F2", CultureInfo.InvariantCulture), "m");
}
