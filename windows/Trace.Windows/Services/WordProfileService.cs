using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using System.Windows.Automation;
using Trace.Core;
using Trace.Windows.Native;

namespace Trace.Windows.Services;

internal sealed record MonitorContext(bool Enabled, bool TrackWords, int Generation, HashSet<string> Excluded);
internal sealed record WordDelta(string Day, Dictionary<string, long> Before, Dictionary<string, long> After, int Characters, int Generation);
internal sealed record FocusPrivacy(uint ProcessId, bool Protected);

// Potentially slow UI Automation providers run only on this independent MTA thread.
// Only aggregate word deltas leave the thread. Raw field values never enter a log or file.
internal sealed class WordProfileService : IDisposable
{
    private MonitorContext context = new(false, false, 0, new(StringComparer.OrdinalIgnoreCase));
    private readonly ConcurrentQueue<WordDelta> pending = new();
    private readonly ManualResetEventSlim stop = new();
    private readonly Thread thread;
    private long lastKeyTicks, suppressUntil;
    private uint lastKeyProcess;
    private TextDraft? draft;
    private string? identity;
    private string day = "";
    private Dictionary<string, long> contributed = [];
    private int characters, generation = -1;
    private long seenKey;
    private volatile string status = "词语画像已关闭";
    private FocusPrivacy privacy = new(0, false);
    internal string Status => status;
    internal FocusPrivacy Privacy => Volatile.Read(ref privacy);
    internal WordProfileService()
    {
        thread = new Thread(Run) { IsBackground = true, Name = "Trace accessibility sampling" };
        thread.SetApartmentState(ApartmentState.MTA);
        thread.Start();
    }
    internal void Update(MonitorContext value) => Volatile.Write(ref context, value);
    internal void NotifyKey(InputSample input)
    {
        Volatile.Write(ref lastKeyProcess, input.ProcessId);
        Interlocked.Exchange(ref lastKeyTicks, input.At.ToUniversalTime().Ticks);
        if (input.SuppressWords) Interlocked.Exchange(ref suppressUntil, DateTime.UtcNow.AddSeconds(1).Ticks);
    }
    internal bool TryRead(out WordDelta? delta) => pending.TryDequeue(out delta);
    private void Reset()
    {
        draft = null; identity = null; contributed = []; characters = 0;
        seenKey = Interlocked.Read(ref lastKeyTicks);
    }
    private void Run()
    {
        global::Windows.Data.Text.WordsSegmenter? segmenter = null;
        while (!stop.Wait(200))
        {
            try
            {
                var current = Volatile.Read(ref context);
                if (!current.Enabled || !Win32.IsDefaultDesktop())
                { Reset(); Volatile.Write(ref privacy, new(0, true)); status = "统计已暂停或处于安全桌面"; continue; }
                var foreground = Win32.ForegroundProcess();
                if (foreground == 0 || foreground == (uint)Environment.ProcessId)
                { Reset(); status = current.TrackWords ? "当前应用已跳过" : "词语画像已关闭"; continue; }
                string executable;
                try { using var process = Process.GetProcessById((int)foreground); executable = process.ProcessName + ".exe"; }
                catch { Reset(); status = "当前应用无法读取"; continue; }
                if (current.Excluded.Contains(executable))
                { Reset(); Volatile.Write(ref privacy, new(foreground, true)); status = "当前应用已排除"; continue; }
                var element = AutomationElement.FocusedElement;
                if (element is null || element.Current.ProcessId != foreground)
                { Reset(); status = "未找到受支持输入框"; continue; }
                var password = element.Current.IsPassword;
                var ancestor = element;
                for (var i = 0; !password && i < 3; i++)
                {
                    ancestor = TreeWalker.ControlViewWalker.GetParent(ancestor);
                    if (ancestor is null || ancestor.Current.ProcessId != foreground) break;
                    password |= ancestor.Current.IsPassword;
                }
                Volatile.Write(ref privacy, new(foreground, password));
                if (password) { Reset(); status = "密码输入框，已跳过"; continue; }
                if (!current.TrackWords) { Reset(); status = "词语画像已关闭"; continue; }
                if (DateTime.UtcNow.Ticks < Interlocked.Read(ref suppressUntil))
                { Reset(); status = "快捷键 / 粘贴后暂缓采样"; continue; }
                var control = element.Current.ControlType;
                if (control != ControlType.Edit && control != ControlType.ComboBox)
                { Reset(); status = "此控件不提供可编辑文本"; continue; }
                var runtimeId = foreground + ":" + string.Join("-", element.GetRuntimeId());
                var today = SavedStatistics.DayKey(DateTime.Now);
                var keyTicks = Interlocked.Read(ref lastKeyTicks);
                var sameField = identity == runtimeId && day == today && generation == current.Generation;
                if (sameField && (keyTicks <= seenKey || Volatile.Read(ref lastKeyProcess) != foreground || DateTime.UtcNow.Ticks - keyTicks < TimeSpan.TicksPerMillisecond * 650)) continue;
                string? text = null;
                if (element.TryGetCurrentPattern(ValuePattern.Pattern, out var valueObject) && valueObject is ValuePattern value)
                {
                    if (value.Current.IsReadOnly) { Reset(); status = "只读输入框，已跳过"; continue; }
                    text = value.Current.Value;
                }
                else if (control == ControlType.Edit && element.TryGetCurrentPattern(TextPattern.Pattern, out var textObject) && textObject is TextPattern pattern)
                    text = pattern.DocumentRange.GetText(30001);
                if (text is null || text.Length > 30000)
                { Reset(); status = "此输入框不支持画像或内容过长"; continue; }
                // Focus, settings, and foreground can change during a slow provider call.
                if (Win32.ForegroundProcess() != foreground || !Win32.IsDefaultDesktop() || !ReferenceEquals(current, Volatile.Read(ref context)) &&
                    (Volatile.Read(ref context).Generation != current.Generation || !Volatile.Read(ref context).Enabled || !Volatile.Read(ref context).TrackWords))
                { Reset(); continue; }
                var focusedNow = AutomationElement.FocusedElement;
                if (focusedNow is null || !Automation.Compare(element, focusedNow) || focusedNow.Current.IsPassword)
                { Reset(); continue; }
                if (!sameField)
                {
                    Reset(); identity = runtimeId; day = today; generation = current.Generation;
                    draft = new(text); seenKey = keyTicks;
                }
                else if (draft is not null)
                {
                    draft.Update(text);
                    var typed = draft.InsertedText;
                    segmenter ??= new global::Windows.Data.Text.WordsSegmenter("zh-Hans");
                    var words = WordAnalysis.Count(segmenter.GetTokens(typed).Select(x => x.Text));
                    var count = WordAnalysis.CharacterCount(typed);
                    pending.Enqueue(new(day, contributed, words, count - characters, generation));
                    contributed = words; characters = count; seenKey = keyTicks;
                }
                status = "本地分析 · " + executable;
            }
            catch (Exception)
            {
                Reset(); status = "此应用的辅助功能文本暂不可用";
                // No provider text or exception detail is recorded.
            }
        }
        Reset();
    }
    public void Dispose() => stop.Set(); // A hung external UIA provider must never block application exit.
}
