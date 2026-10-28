using System;
using System.Collections.Generic;

namespace Trace.Windows.Native;

internal static class KeyNames
{
    private static readonly Dictionary<uint, string> Names = new()
    {
        [0x08]="Backspace",[0x09]="Tab",[0x0D]="Enter",[0x13]="Pause",[0x14]="Caps",[0x1B]="Esc",[0x20]="Space",
        [0x21]="PgUp",[0x22]="PgDn",[0x23]="End",[0x24]="Home",[0x25]="←",[0x26]="↑",[0x27]="→",[0x28]="↓",
        [0x2C]="PrtSc",[0x2D]="Insert",[0x2E]="Delete",[0x5B]="Win",[0x5C]="RWin",[0x5D]="Menu",
        [0x6A]="Num *",[0x6B]="Num +",[0x6D]="Num -",[0x6E]="Num .",[0x6F]="Num /",[0x90]="NumLock",[0x91]="Scroll",
        [0xA0]="Shift",[0xA1]="RShift",[0xA2]="Ctrl",[0xA3]="RCtrl",[0xA4]="Alt",[0xA5]="RAlt",
        [0xBA]=";",[0xBB]="=",[0xBC]=",",[0xBD]="-",[0xBE]=".",[0xBF]="/",[0xC0]="`",[0xDB]="[",[0xDC]="\\",[0xDD]="]",[0xDE]="'"
    };
    internal static string For(uint key, uint scan, bool extended)
    {
        if (key == 0x10) return scan == 0x36 ? "RShift" : "Shift";
        if (key == 0x11) return extended ? "RCtrl" : "Ctrl";
        if (key == 0x12) return extended ? "RAlt" : "Alt";
        if (key == 0x0D && extended) return "Num Enter";
        if (key is >= 0x41 and <= 0x5A or >= 0x30 and <= 0x39) return ((char)key).ToString();
        if (key is >= 0x70 and <= 0x87) return "F" + (key - 0x6F);
        if (key is >= 0x60 and <= 0x69) return "Num " + (key - 0x60);
        return Names.GetValueOrDefault(key, "Key " + key);
    }
}
