using System.Runtime.InteropServices;
using System.Windows.Threading;

namespace DiktaWindows.Services;

public static class ClipboardManager
{
    private const ushort VK_CONTROL = 0x11;
    private const ushort VK_V = 0x56;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const int INPUT_KEYBOARD = 1;

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HARDWAREINPUT
    {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public int type;
        public InputUnion u;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    public static async Task CopyAndPasteAsync(string text)
    {
        // Set clipboard on UI thread using WinForms clipboard (avoids CLIPBRD_E_CANT_OPEN)
        await System.Windows.Application.Current.Dispatcher.InvokeAsync(() =>
        {
            System.Windows.Forms.Clipboard.SetText(text);
        });

        // Brief delay to ensure clipboard is ready
        await Task.Delay(50);

        // Simulate Ctrl+V atomically via SendInput
        var inputs = new INPUT[4];

        // Ctrl down
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].u.ki = new KEYBDINPUT { wVk = VK_CONTROL };

        // V down
        inputs[1].type = INPUT_KEYBOARD;
        inputs[1].u.ki = new KEYBDINPUT { wVk = VK_V };

        // V up
        inputs[2].type = INPUT_KEYBOARD;
        inputs[2].u.ki = new KEYBDINPUT { wVk = VK_V, dwFlags = KEYEVENTF_KEYUP };

        // Ctrl up
        inputs[3].type = INPUT_KEYBOARD;
        inputs[3].u.ki = new KEYBDINPUT { wVk = VK_CONTROL, dwFlags = KEYEVENTF_KEYUP };

        SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
    }
}
