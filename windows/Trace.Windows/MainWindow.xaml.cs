using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;
using Trace.Windows.Native;
using Trace.Windows.Services;
using Trace.Windows.ViewModels;

namespace Trace.Windows;

public partial class MainWindow : Window
{
    private readonly MainViewModel model;
    private readonly AppController? controller;
    private readonly List<(string Name, Border Border, TextBlock Label, TextBlock Count)> caps = [];
    private bool ready;
    internal MainWindow(MainViewModel model, AppController? controller)
    {
        this.model = model; this.controller = controller;
        InitializeComponent(); DataContext = model;
        BuildKeyboard(); ShowTab("overview");
        ThemeChoice.SelectedIndex = model.Store.Preferences.Theme == "dark" ? 1 : 0;
        WordToggle.IsChecked = model.Store.Data.WordTrackingEnabled;
        model.SnapshotChanged += UpdateKeyboard;
        ready = true;
        SourceInitialized += (_, _) => ThemeManager.ApplyTitleBar(this);
        if (controller is not null)
        {
            Closing += ClosingToTray;
            StateChanged += (_, _) =>
            {
                if (controller.Changing || controller.Exiting) return;
                if (WindowState == WindowState.Minimized) controller.HideToTray();
                else if (controller.IsFloating || controller.IsTrayHidden) controller.ShowDashboard();
            };
            Deactivated += (_, _) =>
            {
                if (controller.DialogDepth > 0 || controller.Changing || controller.IsTrayHidden || !IsVisible) return;
                Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(() =>
                {
                    if (!controller.Exiting && !controller.Changing && !controller.IsTrayHidden && IsVisible && controller.DialogDepth == 0 && WindowState != WindowState.Minimized && Win32.ForegroundProcess() != Environment.ProcessId)
                        controller.ShowFloating();
                }));
            };
        }
    }
    private void ClosingToTray(object? sender, CancelEventArgs args)
    {
        if (controller is not null && !controller.Exiting) { args.Cancel = true; controller.HideToTray(); }
    }
    internal void ShowTab(string tab)
    {
        OverviewPage.Visibility = tab == "overview" ? Visibility.Visible : Visibility.Collapsed;
        KeyboardPage.Visibility = tab == "keyboard" ? Visibility.Visible : Visibility.Collapsed;
        WordsPage.Visibility = tab == "words" ? Visibility.Visible : Visibility.Collapsed;
        SettingsPage.Visibility = tab == "settings" ? Visibility.Visible : Visibility.Collapsed;
        PageTitle.Text = tab switch { "keyboard" => "每一次敲击，都有回响。", "words" => "你留下的词语。", "settings" => "按你的方式，记录。", _ => "今天，也在创造。" };
        foreach (var navigation in new[] { OverviewNav, KeyboardNav, WordsNav, SettingsNav })
        {
            navigation.SetResourceReference(Control.BackgroundProperty, (string)navigation.Tag == tab ? "QuietBrush" : "SidebarBrush");
            navigation.SetResourceReference(Control.ForegroundProperty, (string)navigation.Tag == tab ? "AccentBrush" : "MutedBrush");
            navigation.FontWeight = (string)navigation.Tag == tab ? FontWeights.SemiBold : FontWeights.Normal;
        }
        RootScroll.ScrollToTop();
    }
    private void NavigateClick(object sender, RoutedEventArgs args) { if (sender is Button button) ShowTab((string)button.Tag); }
    private void PeriodChanged(object sender, RoutedEventArgs args) { if (ready && sender is RadioButton radio) model.Cumulative = (string)radio.Tag == "all"; }
    private void CompactClick(object sender, RoutedEventArgs args) => controller?.ShowFloating();
    private void PauseClick(object sender, RoutedEventArgs args)
    {
        model.Store.Paused = !model.Store.Paused; model.Store.InvalidateText(); model.Refresh(true);
    }
    private void ThemeChanged(object sender, SelectionChangedEventArgs args)
    {
        if (!ready || ThemeChoice.SelectedItem is not ComboBoxItem item) return;
        model.Store.Preferences.Theme = (string)item.Tag;
        ThemeManager.Apply(model.Store.Preferences.Theme); model.Store.SavePreferences(); UpdateKeyboard();
    }
    private void WordTrackingChanged(object sender, RoutedEventArgs args)
    {
        if (!ready) return;
        model.Store.SetWordTracking(WordToggle.IsChecked == true); model.Refresh(true);
    }
    private T Dialog<T>(Func<T> action) => controller is null ? action() : controller.Dialog(action);
    private void Error(Exception error) => Dialog(() => MessageBox.Show(this, error.Message, "迹 · Trace", MessageBoxButton.OK, MessageBoxImage.Information));
    private void AddExcludedClick(object sender, RoutedEventArgs args)
    {
        try { model.Store.AddExcluded(ExcludedName.Text); model.Store.Save(); model.Refresh(true); ExcludedName.Clear(); }
        catch (Exception error) { Error(error); }
    }
    private void BrowseExcludedClick(object sender, RoutedEventArgs args)
    {
        var dialog = new OpenFileDialog { Title = "选择要排除的应用", Filter = "应用程序 (*.exe)|*.exe", CheckFileExists = true };
        if (Dialog(() => dialog.ShowDialog(this)) != true) return;
        try { model.Store.AddExcluded(Path.GetFileName(dialog.FileName)); model.Store.Save(); model.Refresh(true); }
        catch (Exception error) { Error(error); }
    }
    private void RemoveExcludedClick(object sender, RoutedEventArgs args)
    {
        if (ExcludedList.SelectedItem is not string selected) return;
        model.Store.RemoveExcluded(selected); model.Store.Save(); model.Refresh(true);
    }
    private void ExportClick(object sender, RoutedEventArgs args)
    {
        var dialog = new SaveFileDialog { Title = "导出本地统计", Filter = "JSON 统计 (*.json)|*.json", FileName = "Trace-export-" + DateTime.Now.ToString("yyyy-MM-dd") + ".json", AddExtension = true, DefaultExt = ".json" };
        if (Dialog(() => dialog.ShowDialog(this)) != true) return;
        try
        {
            if (string.Equals(Path.GetFullPath(dialog.FileName), Path.GetFullPath(model.Store.FilePath), StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("请选择其他文件名，避免覆盖当前统计原文件。");
            model.Store.Export(dialog.FileName);
        }
        catch (Exception error) { Error(error); }
    }
    private void ClearWordsClick(object sender, RoutedEventArgs args)
    {
        if (Dialog(() => MessageBox.Show(this, "清空所有日期的词语画像？鼠标和按键统计会保留。", "迹 · Trace", MessageBoxButton.OKCancel, MessageBoxImage.Question)) != MessageBoxResult.OK) return;
        model.Store.ClearWords(); model.Refresh(true);
    }
    private void ClearAllClick(object sender, RoutedEventArgs args)
    {
        if (Dialog(() => MessageBox.Show(this, "清空所有统计？此操作无法撤销，建议先导出 JSON。", "迹 · Trace", MessageBoxButton.OKCancel, MessageBoxImage.Warning)) != MessageBoxResult.OK) return;
        model.Store.ClearAll(); model.Refresh(true);
    }
    private void RecoverClick(object sender, RoutedEventArgs args) { model.Store.BackupAndRetry(); model.Refresh(true); }
    private void BuildKeyboard()
    {
        var rows = new[]
        {
            new[] { "Esc", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "Delete" },
            new[] { "`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Backspace" },
            new[] { "Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\" },
            new[] { "Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "Enter" },
            new[] { "Shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "RShift", "↑" },
            new[] { "Ctrl", "Win", "Alt", "Space", "RAlt", "RWin", "Menu", "RCtrl", "←", "↓", "→" }
        };
        foreach (var row in rows)
        {
            var panel = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 3, 0, 3) };
            foreach (var key in row)
            {
                var width = key == "Space" ? 204 : key is "Backspace" or "RShift" ? 72 : key is "Caps" or "Enter" or "Shift" ? 64 : key == "Tab" ? 54 : 42;
                var label = new TextBlock { Text = key, FontSize = key.Length > 5 ? 8 : 10, VerticalAlignment = VerticalAlignment.Top, Margin = new Thickness(6, 4, 3, 0), TextWrapping = TextWrapping.NoWrap };
                var count = new TextBlock { FontSize = 8, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(0, 0, 5, 4) };
                var grid = new Grid(); grid.Children.Add(label); grid.Children.Add(count);
                var cap = new Border { Width = width, Height = 43, CornerRadius = new CornerRadius(6), BorderThickness = new Thickness(1), Margin = new Thickness(0, 0, 4, 0), Child = grid };
                cap.SetResourceReference(Border.BorderBrushProperty, "LineBrush");
                panel.Children.Add(cap); caps.Add((key, cap, label, count));
            }
            KeyboardRows.Children.Add(panel);
        }
        UpdateKeyboard();
    }
    private void UpdateKeyboard()
    {
        if (caps.Count == 0) return;
        var background = ((SolidColorBrush)Application.Current.Resources["CardBrush"]).Color;
        var accent = ((SolidColorBrush)Application.Current.Resources["AccentBrush"]).Color;
        foreach (var cap in caps)
        {
            var count = model.KeyCount(cap.Name);
            var fraction = count == 0 ? 0 : .18 + .72 * Math.Sqrt((double)count / Math.Max(1, model.MaxKeyCount));
            byte Mix(byte a, byte b) => (byte)(a + (b - a) * fraction);
            cap.Border.Background = new SolidColorBrush(Color.FromRgb(Mix(background.R, accent.R), Mix(background.G, accent.G), Mix(background.B, accent.B)));
            var ink = fraction > .55 ? "BackgroundBrush" : "TextBrush";
            cap.Label.SetResourceReference(TextBlock.ForegroundProperty, ink); cap.Count.SetResourceReference(TextBlock.ForegroundProperty, ink);
            cap.Count.Text = count > 0 ? MainViewModel.Number(count) : "";
            cap.Border.ToolTip = cap.Name + " · " + MainViewModel.Number(count) + " 次";
        }
    }
}
