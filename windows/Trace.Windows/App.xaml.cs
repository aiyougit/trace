using System;
using System.IO;
using System.Linq;
using System.Threading;
using System.Windows;
using Trace.Windows.Native;
using Trace.Windows.Services;

namespace Trace.Windows;

public partial class App : Application
{
    private Mutex? instance;
    private AppController? controller;
    private bool ownsMutex;
    protected override void OnStartup(StartupEventArgs args)
    {
        base.OnStartup(args);
        if (args.Args.Length == 2 && args.Args[0] == "--render-previews")
        {
            try { ThemeManager.Apply("light"); PreviewRenderer.Run(args.Args[1]); Shutdown(0); }
            catch (Exception error)
            {
                Directory.CreateDirectory(args.Args[1]); File.WriteAllText(Path.Combine(args.Args[1], "preview-error.txt"), error.ToString()); Shutdown(1);
            }
            return;
        }
        instance = new Mutex(true, @"Local\Trace.Desktop.SingleInstance", out ownsMutex);
        if (!ownsMutex)
        {
            var window = Win32.FindWindow(null, "迹 · Trace");
            if (window != IntPtr.Zero) { Win32.ShowWindow(window, 9); Win32.SetForegroundWindow(window); }
            Shutdown(); return;
        }
        try { controller = new(); }
        catch (Exception error)
        {
            MessageBox.Show("无法启动 Trace：" + error.Message, "迹 · Trace", MessageBoxButton.OK, MessageBoxImage.Error); Shutdown(1);
        }
    }
    protected override void OnSessionEnding(SessionEndingCancelEventArgs args) { controller?.Exit(); base.OnSessionEnding(args); }
    protected override void OnExit(ExitEventArgs args)
    {
        controller?.Dispose();
        if (ownsMutex) instance?.ReleaseMutex();
        instance?.Dispose(); base.OnExit(args);
    }
}
