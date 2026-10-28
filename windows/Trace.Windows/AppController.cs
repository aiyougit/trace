using System;
using System.Drawing;
using System.Windows;
using System.Windows.Threading;
using Trace.Core;
using Trace.Windows.Services;
using Trace.Windows.ViewModels;
using Forms = System.Windows.Forms;

namespace Trace.Windows;

internal sealed class AppController : IDisposable
{
    private readonly StatisticsStore store;
    private readonly InputMonitor monitor;
    private readonly MainViewModel model;
    private readonly MainWindow dashboard;
    private readonly FloatingWindow floating;
    private readonly Forms.NotifyIcon tray;
    private readonly Forms.ContextMenuStrip menu;
    private DateTime nextUi;
    internal bool IsFloating => floating.IsVisible;
    internal bool Changing { get; private set; }
    internal bool Exiting { get; private set; }
    internal int DialogDepth { get; private set; }
    internal AppController(StatisticsStore? statistics = null)
    {
        store = statistics ?? new(); ThemeManager.Apply(store.Preferences.Theme);
        monitor = new(store); model = new(store, monitor);
        dashboard = new(model, this); floating = new(model, this);
        Application.Current.MainWindow = dashboard;
        menu = new Forms.ContextMenuStrip();
        void Add(string text, Action action) => menu.Items.Add(text, null, (_, _) => Application.Current.Dispatcher.BeginInvoke(action));
        Add("展开统计面板", ShowDashboard); Add("显示悬浮条", ShowFloating);
        var pause = new Forms.ToolStripMenuItem("暂停统计");
        pause.Click += (_, _) => { store.Paused = !store.Paused; store.InvalidateText(); model.Refresh(true); };
        menu.Items.Add(pause); menu.Items.Add(new Forms.ToolStripSeparator()); Add("退出 Trace", Exit);
        menu.Opening += (_, _) => pause.Text = store.Paused ? "继续统计" : "暂停统计";
        using var stream = Application.GetResourceStream(new Uri("pack://application:,,,/Assets/Trace.ico")).Stream;
        using var icon = new Icon(stream);
        tray = new Forms.NotifyIcon { Icon = (Icon)icon.Clone(), Text = "迹 · Trace", ContextMenuStrip = menu, Visible = true };
        tray.DoubleClick += (_, _) => ShowDashboard();
        monitor.Updated += () =>
        {
            if (DateTime.UtcNow < nextUi) return;
            nextUi = DateTime.UtcNow.AddMilliseconds(500); model.Refresh();
            var tip = $"迹 · Trace — 今日 {model.TodayDistance} {model.TodayUnit} / {model.TodayKeys} 次";
            tray.Text = tip.Length > 63 ? tip[..63] : tip;
        };
        Changing = true;
        if (store.Preferences.Compact) { dashboard.WindowState = WindowState.Minimized; dashboard.Show(); floating.Show(); }
        else dashboard.Show();
        Changing = false;
    }
    internal void ShowFloating()
    {
        if (Exiting || Changing) return;
        Changing = true;
        try
        {
            dashboard.WindowState = WindowState.Minimized; // Keep an entry in the Windows taskbar.
            if (!floating.IsVisible) floating.Show();
            store.Preferences.Compact = true; store.SavePreferences();
        }
        finally { Changing = false; }
    }
    internal void ShowDashboard()
    {
        if (Exiting || Changing) return;
        Changing = true;
        try
        {
            floating.Hide(); dashboard.Show();
            if (dashboard.WindowState == WindowState.Minimized) dashboard.WindowState = WindowState.Normal;
            dashboard.Activate();
            store.Preferences.Compact = false; store.SavePreferences();
        }
        finally { Changing = false; }
    }
    internal T Dialog<T>(Func<T> action)
    {
        DialogDepth++;
        try { return action(); }
        finally { DialogDepth--; }
    }
    internal void Exit()
    {
        if (Exiting) return;
        Exiting = true; Application.Current.Shutdown();
    }
    public void Dispose()
    {
        Exiting = true; monitor.Dispose(); tray.Visible = false; tray.Icon?.Dispose(); tray.Dispose(); menu.Dispose();
    }
}
