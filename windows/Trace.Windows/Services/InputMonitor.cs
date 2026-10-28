using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Windows.Threading;
using Microsoft.Win32;
using Trace.Core;
using Trace.Windows.Native;

namespace Trace.Windows.Services;

internal sealed class InputMonitor : IDisposable
{
    private readonly StatisticsStore store;
    private readonly InputHooks hooks;
    private readonly WordProfileService words;
    private readonly DispatcherTimer timer;
    private readonly Dictionary<uint, (string Name, DateTime Until)> processNames = [];
    private volatile bool locked;
    private DateTime nextSave = DateTime.Now.AddSeconds(10), nextDisplayRefresh = DateTime.Now;
    internal string Status => store.Paused ? "统计已暂停" : !hooks.Listening ? hooks.Error ?? "监听尚未连接" : locked ? "已锁屏，暂停采样" : hooks.Dropped > 0 ? "监听已连接 · 曾跳过拥堵采样" : "监听已连接 · 仅本机保存";
    internal string TextStatus => words.Status;
    internal bool Listening => hooks.Listening;
    internal event Action? Updated;
    internal InputMonitor(StatisticsStore store)
    {
        this.store = store;
        hooks = new(); words = new();
        SystemEvents.SessionSwitch += SessionSwitch;
        timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        timer.Tick += Tick; timer.Start();
    }
    private void SessionSwitch(object sender, SessionSwitchEventArgs args)
    {
        if (args.Reason is SessionSwitchReason.SessionLock or SessionSwitchReason.SessionLogoff or SessionSwitchReason.ConsoleDisconnect or SessionSwitchReason.RemoteDisconnect)
        { locked = true; hooks.Enabled = false; }
        else if (args.Reason is SessionSwitchReason.SessionUnlock or SessionSwitchReason.SessionLogon or SessionSwitchReason.ConsoleConnect or SessionSwitchReason.RemoteConnect)
            locked = false;
    }
    private string Executable(uint id)
    {
        if (processNames.TryGetValue(id, out var entry) && entry.Until > DateTime.Now) return entry.Name;
        try
        {
            using var process = Process.GetProcessById((int)id);
            var name = process.ProcessName + ".exe";
            processNames[id] = (name, DateTime.Now.AddSeconds(3));
            if (processNames.Count > 256) processNames.Clear();
            return name;
        }
        catch { return ""; }
    }
    private void Tick(object? sender, EventArgs args)
    {
        var enabled = !store.Paused && !locked && Win32.IsDefaultDesktop();
        hooks.Enabled = enabled;
        words.Update(new(enabled, store.Data.WordTrackingEnabled, store.TextGeneration, new(store.Data.ExcludedExecutables, StringComparer.OrdinalIgnoreCase)));
        for (var i = 0; i < 20000 && hooks.TryRead(out var input); i++)
        {
            if (!enabled) continue;
            if (input.Meters > 0) store.RecordDistance(input.Meters, input.At);
            else if (input.Key > 0 && input.ProcessId != 0 && input.ProcessId != Environment.ProcessId)
            {
                var name = Executable(input.ProcessId);
                var privacy = words.Privacy;
                if (name.Length == 0 || store.IsExcluded(name) || privacy.ProcessId == input.ProcessId && privacy.Protected) continue;
                store.RecordKey(KeyNames.For(input.Key, input.Scan, input.Extended), input.At);
                if (store.Data.WordTrackingEnabled) words.NotifyKey(input);
            }
        }
        while (words.TryRead(out var delta))
            if (delta is not null && enabled) store.ReviseWords(delta.Day, delta.Before, delta.After, delta.Characters, delta.Generation);
        if (DateTime.Now >= nextSave) { store.Save(); nextSave = DateTime.Now.AddSeconds(10); }
        if (DateTime.Now >= nextDisplayRefresh) { hooks.RefreshScreens(); nextDisplayRefresh = DateTime.Now.AddSeconds(5); }
        Updated?.Invoke();
    }
    public void Dispose()
    {
        timer.Stop(); SystemEvents.SessionSwitch -= SessionSwitch;
        hooks.Enabled = false; words.Update(new(false, false, store.TextGeneration + 1, new()));
        words.Dispose(); hooks.Dispose(); store.Save(); store.SavePreferences();
    }
}
