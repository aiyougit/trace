using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Trace.Core;

namespace Trace.Windows.Native;

// Explicit CI diagnostics use isolated temporary stores; no UI Automation text or user-data files.
internal static class NativeDiagnostics
{
    internal static void Run(string output)
    {
        using (var hooks = new InputHooks())
        {
            if (!hooks.Listening) throw new InvalidOperationException(hooks.Error ?? "Input hook initialization timed out");
            if (hooks.ScreenCount == 0) throw new InvalidOperationException("No display geometry available");
        }
        var words = LocalWordSegmenter.Count("软件 开发 TRACE trace");
        if (words.GetValueOrDefault("trace") != 2 || !words.ContainsKey("软件"))
            throw new InvalidOperationException("Bundled Chinese/English dictionary segmentation failed");
        var directory = Path.Combine(Path.GetTempPath(), "TraceNativeChecks-" + Guid.NewGuid());
        try
        {
            var statistics = new StatisticsStore(directory) { Paused = true };
            using (var controller = new AppController(statistics))
            {
                var dashboard = Application.Current.MainWindow!;
                var floating = Application.Current.Windows.OfType<FloatingWindow>().Single();
                if (dashboard.Topmost || !dashboard.ShowInTaskbar) throw new InvalidOperationException("Dashboard window level/taskbar check failed");
                controller.ShowFloating();
                if (!floating.IsVisible || !floating.Topmost || floating.ShowInTaskbar || dashboard.WindowState != WindowState.Minimized)
                    throw new InvalidOperationException("Floating window mode check failed");
                controller.ShowDashboard();
                if (floating.IsVisible || !dashboard.IsVisible || dashboard.WindowState != WindowState.Normal)
                    throw new InvalidOperationException("Dashboard restore check failed");
                void CheckTray(string operation)
                {
                    // Flush pending Deactivated callbacks: they must not bring the floating strip back.
                    Application.Current.Dispatcher.Invoke(() => { }, DispatcherPriority.Background);
                    if (!controller.IsTrayHidden || !controller.TrayVisible || dashboard.IsVisible || floating.IsVisible || dashboard.ShowInTaskbar || controller.Exiting || !statistics.Paused)
                        throw new InvalidOperationException(operation + " must hide both windows to tray without exiting or changing pause state");
                }
                void CheckRestored()
                {
                    if (controller.IsTrayHidden || floating.IsVisible || !dashboard.IsVisible || !dashboard.ShowInTaskbar || dashboard.Topmost || dashboard.WindowState != WindowState.Normal)
                        throw new InvalidOperationException("Restore from tray must show a normal taskbar window");
                }
                for (var cycle = 0; cycle < 2; cycle++)
                {
                    dashboard.WindowState = WindowState.Minimized;
                    CheckTray("Minimize");
                    controller.ShowDashboard(); CheckRestored();
                    dashboard.Close();
                    CheckTray("Close button / Alt+F4");
                    // A second launch restores the hidden HWND; its normal-state event must restore taskbar visibility too.
                    dashboard.WindowState = WindowState.Normal;
                    CheckRestored();
                }
                controller.ShowFloating();
                var floatingMenu = ((FrameworkElement)floating.Content).ContextMenu;
                if (floatingMenu.Items.OfType<MenuItem>().Any(item => item.Header?.ToString()?.Contains("退出", StringComparison.Ordinal) == true))
                    throw new InvalidOperationException("Exit must only be offered in the system tray menu");
                floatingMenu.Items.OfType<MenuItem>().Single(item => item.Header?.ToString() == "隐藏到系统托盘").RaiseEvent(new RoutedEventArgs(MenuItem.ClickEvent));
                CheckTray("Floating strip hide menu");
                controller.ShowFloating();
                if (controller.IsTrayHidden || !floating.IsVisible || !dashboard.ShowInTaskbar)
                    throw new InvalidOperationException("Floating strip restore from tray failed");
                floating.Close(); CheckTray("Floating strip close");
                controller.ShowDashboard(); CheckRestored();
                var menuLabels = controller.TrayMenu.Items.OfType<System.Windows.Forms.ToolStripMenuItem>().Select(item => item.Text).ToArray();
                if (menuLabels.Count(label => label == "退出 Trace") != 1 || menuLabels.Last() != "退出 Trace" || !menuLabels.Contains("展开统计面板") || !menuLabels.Contains("显示悬浮条"))
                    throw new InvalidOperationException("Tray menu restore / exit commands are missing");
            }
            foreach (Window window in Application.Current.Windows.Cast<Window>().ToArray()) window.Close();
        }
        finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
        var path = Path.GetFullPath(output);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, "PASS — packaged native hook initialization/cleanup, monitor geometry, bundled offline Chinese/English segmentation. Dashboard startup, floating/taskbar modes, repeated minimize/close-to-tray, deferred deactivation, tray restore, floating hide/close and tray-only exit menu checks passed. Temporary data only; no user statistics accessed.");
    }
}
