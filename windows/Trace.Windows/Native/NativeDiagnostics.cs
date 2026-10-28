using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
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
        var path = Path.GetFullPath(output);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, "PASS — packaged native hook initialization/cleanup, monitor geometry, bundled offline Chinese/English segmentation. No statistics saved.");
    }
}
