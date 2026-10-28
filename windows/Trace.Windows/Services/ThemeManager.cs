using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Interop;
using System.Windows;
using System.Windows.Media;

namespace Trace.Windows.Services;

internal static class ThemeManager
{
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int size);
    internal static void ApplyTitleBar(Window window)
    {
        var handle = new WindowInteropHelper(window).Handle;
        if (handle == IntPtr.Zero) return;
        var dark = Current == "dark" ? 1 : 0;
        DwmSetWindowAttribute(handle, 20, ref dark, sizeof(int));
    }
    internal static string Current { get; private set; } = "light";
    internal static void Apply(string theme)
    {
        Current = theme == "dark" ? "dark" : "light";
        var light = Current == "light";
        var colors = new Dictionary<string, string>
        {
            ["BackgroundBrush"] = light ? "#F6F0E3" : "#101619",
            ["SidebarBrush"] = light ? "#EDE4D2" : "#0C1114",
            ["CardBrush"] = light ? "#FFFBF2" : "#182125",
            ["TextBrush"] = light ? "#4D4639" : "#F5F7F6",
            ["MutedBrush"] = light ? "#7E705D" : "#829297",
            ["AccentBrush"] = light ? "#68764B" : "#9DE8CC",
            ["SecondaryBrush"] = light ? "#967044" : "#A4C8F5",
            ["WordBrush"] = light ? "#8B7168" : "#C9BAF0",
            ["LineBrush"] = light ? "#21786341" : "#19FFFFFF",
            ["QuietBrush"] = light ? "#10786341" : "#12FFFFFF",
            ["FloatingBrush"] = light ? "#EAF6F0E3" : "#EE101619"
        };
        // Respect the Windows transparency preference without making text translucent.
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            if (!SystemParameters.ClientAreaAnimation || key?.GetValue("EnableTransparency") is int enabled && enabled == 0)
                colors["FloatingBrush"] = colors["BackgroundBrush"];
        }
        catch { colors["FloatingBrush"] = colors["BackgroundBrush"]; }
        foreach (var pair in colors)
        {
            var brush = new SolidColorBrush((Color)ColorConverter.ConvertFromString(pair.Value)); brush.Freeze();
            Application.Current.Resources[pair.Key] = brush;
        }
        foreach (Window window in Application.Current.Windows) ApplyTitleBar(window);
    }
}
