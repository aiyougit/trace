using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Trace.Core;
using Trace.Windows.Services;
using Trace.Windows.ViewModels;

namespace Trace.Windows;

internal static class PreviewRenderer
{
    internal static void Run(string output)
    {
        Directory.CreateDirectory(output);
        var directory = Path.Combine(Path.GetTempPath(), "TracePreviews-" + Guid.NewGuid());
        try
        {
            var store = new StatisticsStore(directory);
            store.RecordDistance(1286.42);
            var keys = new[] { "Space", "E", "A", "Ctrl", "S", "Enter", "Backspace", "T", "O", "N", "I", "R", "W", "D", "Shift", "C", "V", "L" };
            for (var index = 0; index < keys.Length; index++)
                for (var i = 0; i < 460 - index * 23; i++) store.RecordKey(keys[index], DateTime.Today.AddHours(7 + i % 15));
            store.SetWordTracking(true);
            store.ReviseWords(SavedStatistics.DayKey(DateTime.Now), new Dictionary<string, long>(), new Dictionary<string, long>
            { ["设计"] = 128, ["开发"] = 98, ["软件"] = 76, ["灵感"] = 64, ["swift"] = 48, ["用户体验"] = 35, ["工作"] = 31, ["生活"] = 22, ["交互"] = 18, ["trace"] = 15 }, 3268, store.TextGeneration);
            var model = new MainViewModel(store);
            foreach (var theme in new[] { "light", "dark" })
            {
                ThemeManager.Apply(theme); store.Preferences.Theme = theme;
                var window = new MainWindow(model, null);
                foreach (var page in new[] { "overview", "keyboard", "words" })
                {
                    window.ShowTab(page);
                    Render(window.Root, 1040, 760, Path.Combine(output, $"{page}-windows-{theme}.png"));
                    if (((SolidColorBrush)window.PageTitle.Foreground).Color != ((SolidColorBrush)Application.Current.Resources["TextBrush"]).Color)
                        throw new InvalidOperationException("Window text does not match the selected theme");
                }
                var floating = new FloatingWindow(model, null);
                Render(floating.Root, 220, 44, Path.Combine(output, $"floating-windows-{theme}.png"));
                if (window.KeyboardRows.Children.Count != 6 || model.KeyText != "4,761" || model.TodayDistance != "1.29" || model.Words.Count != 10)
                    throw new InvalidOperationException("WPF preview / binding smoke check failed");
                window.Close(); floating.Close();
            }
            File.WriteAllText(Path.Combine(output, "smoke-checks.txt"), "PASS — WPF views, six keyboard rows, daily totals, word fixtures, both themes, floating strip. No monitoring started. Synthetic data only.");
        }
        finally { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
    }
    private static void Render(FrameworkElement element, int width, int height, string path)
    {
        element.Width = width; element.Height = height;
        element.Measure(new Size(width, height)); element.Arrange(new Rect(0, 0, width, height)); element.UpdateLayout();
        Application.Current.Dispatcher.Invoke(DispatcherPriority.ApplicationIdle, new Action(() => { }));
        element.UpdateLayout();
        var bitmap = new RenderTargetBitmap(width * 2, height * 2, 192, 192, PixelFormats.Pbgra32);
        bitmap.Render(element);
        var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var file = File.Create(path); encoder.Save(file);
    }
}
