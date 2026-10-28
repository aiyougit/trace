using System;
using System.Linq;
using System.Windows;
using System.Windows.Input;
using Trace.Windows.ViewModels;

namespace Trace.Windows;

public partial class FloatingWindow : Window
{
    private readonly AppController? controller;
    private readonly MainViewModel model;
    internal FloatingWindow(MainViewModel model, AppController? controller)
    {
        this.model = model; this.controller = controller;
        InitializeComponent(); DataContext = model;
        if (model.Store.Preferences.FloatingLeft is { } left && double.IsFinite(left)) Left = left;
        else Left = SystemParameters.WorkArea.Right - Width - 24;
        if (model.Store.Preferences.FloatingTop is { } top && double.IsFinite(top)) Top = top;
        else Top = SystemParameters.WorkArea.Bottom - Height - 28;
        Loaded += (_, _) => EnsureVisible();
        Closing += (_, args) => { if (controller is not null && !controller.Exiting) { args.Cancel = true; Hide(); } };
    }
    private void EnsureVisible()
    {
        var origin = PointToScreen(new Point(0, 0));
        var dpi = System.Windows.Media.VisualTreeHelper.GetDpi(this);
        var box = new System.Drawing.Rectangle((int)origin.X, (int)origin.Y, (int)(Width * dpi.DpiScaleX), (int)(Height * dpi.DpiScaleY));
        if (!System.Windows.Forms.Screen.AllScreens.Any(s => s.WorkingArea.IntersectsWith(box)))
        { Left = SystemParameters.WorkArea.Right - Width - 24; Top = SystemParameters.WorkArea.Bottom - Height - 28; }
    }
    private void DragOrExpand(object sender, MouseButtonEventArgs args)
    {
        if (controller is null) return;
        if (args.ClickCount == 2) { controller.ShowDashboard(); return; }
        try { DragMove(); } catch (InvalidOperationException) { }
        EnsureVisible();
        model.Store.Preferences.FloatingLeft = Left; model.Store.Preferences.FloatingTop = Top; model.Store.SavePreferences();
    }
    private void ExpandClick(object sender, RoutedEventArgs args) => controller?.ShowDashboard();
    private void PauseClick(object sender, RoutedEventArgs args)
    {
        model.Store.Paused = !model.Store.Paused; model.Store.InvalidateText(); model.Refresh(true);
    }
    private void HideClick(object sender, RoutedEventArgs args) => Hide();
    private void ExitClick(object sender, RoutedEventArgs args) => controller?.Exit();
}
