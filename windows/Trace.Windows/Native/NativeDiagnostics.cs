using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using Trace.Core;

namespace Trace.Windows.Native;

// Explicit CI diagnostics: no StatisticsStore, UI Automation values, or user-data writes.
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
            using (var controller = new AppController(new StatisticsStore(directory) { Paused = true }))
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
            }
            foreach (Window window in Application.Current.Windows.Cast<Window>().ToArray()) window.Close();
        }
        finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
        var path = Path.GetFullPath(output);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, "PASS — packaged native hook initialization/cleanup, monitor geometry, bundled offline Chinese/English segmentation. Dashboard startup, floating/taskbar modes and restore passed. Temporary data only; no user statistics accessed.");
    }
}
