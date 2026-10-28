using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using Trace.Core;

namespace Trace.Windows.Native;

internal readonly record struct InputSample(DateTime At, double Meters, uint ProcessId, uint Key, uint Scan, bool Extended, bool SuppressWords);

// Hooks live on an independent message-loop thread. Never call UIA, files, or the UI from a hook.
internal sealed class InputHooks : IDisposable
{
    private readonly ConcurrentQueue<InputSample> pending = new();
    private readonly KeyStateTracker keys = new();
    private readonly HashSet<uint> held = new();
    private readonly Win32.HookProc keyboardProc, mouseProc;
    private readonly Thread thread;
    private readonly ManualResetEventSlim ready = new();
    private ScreenGeometry[] screens = [];
    private PointD? previous;
    private IntPtr keyboard, mouse;
    private uint threadId;
    private int queued;
    private volatile bool stopping;
    internal volatile bool Enabled = true;
    internal bool Listening { get; private set; }
    internal string? Error { get; private set; }
    internal long Dropped { get; private set; }
    internal int ScreenCount => Volatile.Read(ref screens).Length;
    internal InputHooks()
    {
        keyboardProc = Keyboard;
        mouseProc = Mouse;
        RefreshScreens();
        thread = new Thread(Run) { IsBackground = true, Name = "Trace input hooks" };
        thread.Start();
        ready.Wait(TimeSpan.FromSeconds(3));
    }
    private void Run()
    {
        threadId = Win32.GetCurrentThreadId();
        Win32.PeekMessage(out _, IntPtr.Zero, 0, 0, 0);
        try
        {
            var module = Win32.GetModuleHandle(null);
            keyboard = Win32.SetWindowsHookEx(13, keyboardProc, module, 0);
            mouse = Win32.SetWindowsHookEx(14, mouseProc, module, 0);
            if (keyboard == IntPtr.Zero || mouse == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            Listening = true; ready.Set();
            while (!stopping && Win32.GetMessage(out _, IntPtr.Zero, 0, 0) > 0) { }
        }
        catch (Exception error) { Error = "监听启动失败：" + error.Message; }
        finally
        {
            Listening = false; ready.Set();
            if (keyboard != IntPtr.Zero) Win32.UnhookWindowsHookEx(keyboard);
            if (mouse != IntPtr.Zero) Win32.UnhookWindowsHookEx(mouse);
        }
    }
    private IntPtr Keyboard(int code, IntPtr message, IntPtr data)
    {
        try
        {
            if (code >= 0)
            {
                var k = Marshal.PtrToStructure<Win32.KeyboardData>(data);
                if ((k.Flags & 0x10) == 0)
                {
                    var id = k.Scan > 0 ? (int)k.Scan | ((k.Flags & 1) != 0 ? 256 : 0) : 512 + (int)k.Key;
                    if (message.ToInt64() is 0x101 or 0x105) { keys.Release(id); held.Remove(k.Key); }
                    else if (message.ToInt64() is 0x100 or 0x104)
                    {
                        held.Add(k.Key);
                        if (keys.Press(id) && Enabled)
                        {
                            var ctrl = held.Any(x => x is 0x11 or 0xA2 or 0xA3);
                            var alt = held.Any(x => x is 0x12 or 0xA4 or 0xA5);
                            var shift = held.Any(x => x is 0x10 or 0xA0 or 0xA1);
                            var win = held.Any(x => x is 0x5B or 0x5C);
                            // Skip shortcut/paste attribution; never try translating raw keystrokes into text.
                            var suppress = ctrl || alt || win || (shift && k.Key == 0x2D);
                            Enqueue(new(DateTime.Now, 0, Win32.ForegroundProcess(), k.Key, k.Scan, (k.Flags & 1) != 0, suppress));
                        }
                    }
                }
            }
        }
        catch { /* A callback must always pass the event through. */ }
        return Win32.CallNextHookEx(IntPtr.Zero, code, message, data);
    }
    private IntPtr Mouse(int code, IntPtr message, IntPtr data)
    {
        try
        {
            if (code >= 0 && message.ToInt64() == 0x200)
            {
                var m = Marshal.PtrToStructure<Win32.MouseData>(data);
                if (!Enabled || (m.Flags & 1) != 0) { previous = null; }
                else
                {
                    var point = new PointD(m.Point.X, m.Point.Y);
                    var geometry = Volatile.Read(ref screens);
                    if (previous is { } last)
                    {
                        foreach (var screen in geometry)
                            if (screen.Contains(last) && screen.Contains(point))
                            { Enqueue(new(DateTime.Now, screen.Distance(last, point), 0, 0, 0, false, false)); break; }
                    }
                    previous = point;
                }
            }
        }
        catch { }
        return Win32.CallNextHookEx(IntPtr.Zero, code, message, data);
    }
    private void Enqueue(InputSample sample)
    {
        if (Interlocked.Increment(ref queued) > 60000) { Interlocked.Decrement(ref queued); Dropped++; previous = null; return; }
        pending.Enqueue(sample);
    }
    internal bool TryRead(out InputSample sample)
    {
        if (!pending.TryDequeue(out sample)) return false;
        Interlocked.Decrement(ref queued); return true;
    }
    internal void RefreshScreens()
    {
        var result = new List<ScreenGeometry>();
        Win32.MonitorEnumProc callback = (IntPtr monitor, IntPtr dc, ref Win32.Rect rect, IntPtr state) =>
        {
            var info = new Win32.MonitorInfo { Size = Marshal.SizeOf<Win32.MonitorInfo>(), Device = "" };
            if (!Win32.GetMonitorInfo(monitor, ref info)) return true;
            var screenDc = Win32.CreateDC("DISPLAY", info.Device, null, IntPtr.Zero);
            var widthMm = screenDc != IntPtr.Zero ? Win32.GetDeviceCaps(screenDc, 4) : 0;
            var heightMm = screenDc != IntPtr.Zero ? Win32.GetDeviceCaps(screenDc, 6) : 0;
            if (screenDc != IntPtr.Zero) Win32.DeleteDC(screenDc);
            result.Add(new(info.Monitor.Left, info.Monitor.Top, info.Monitor.Right - info.Monitor.Left, info.Monitor.Bottom - info.Monitor.Top, widthMm, heightMm));
            return true;
        };
        Win32.EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, callback, IntPtr.Zero);
        Volatile.Write(ref screens, result.ToArray());
        // The callback uses a new geometry array; the next cross-screen segment is naturally skipped.
    }
    public void Dispose()
    {
        stopping = true; Enabled = false;
        if (threadId != 0) Win32.PostThreadMessage(threadId, 0x12, UIntPtr.Zero, IntPtr.Zero);
        thread.Join(TimeSpan.FromSeconds(2));
    }
}
