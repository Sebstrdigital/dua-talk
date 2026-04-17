using System.Runtime.InteropServices;
using System.Windows.Interop;

namespace DiktaWindows.Services;

public class HotkeyManager : IDisposable
{
    private const int WM_HOTKEY = 0x0312;
    private const int HOTKEY_ID = 9000;
    private const uint MOD_NOREPEAT = 0x4000;
    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_SHIFT = 0x0004;
    private const uint MOD_ALT = 0x0001;
    private const uint MOD_WIN = 0x0008;

    private readonly ConfigService _configService;
    private readonly HwndSourceHook _hook;
    private HwndSource? _source;
    private bool _registered;

    public event Action? HotkeyPressed;

    /// <summary>
    /// Raised when the first instance receives the DiktaShowOnboarding broadcast from a second
    /// instance that tried to start. Full foreground activation is handled in F-4; here we just
    /// surface the signal.
    /// </summary>
    public event Action? ShowOnboardingRequested;

    private uint _showOnboardingMsg;

    /// <summary>
    /// Raised when startup hotkey registration fails (e.g. the key combo is already claimed by
    /// another app). Fired during construction — subscribers added after construction will not
    /// receive the initial event; use <see cref="RegistrationFailedOnStartup"/> instead.
    /// </summary>
    public event Action? RegistrationFailed;

    /// <summary>
    /// True when the hotkey could not be registered at startup. Checked by TrayIconManager
    /// after construction so it can surface a balloon even though it wasn't subscribed yet.
    /// </summary>
    public bool RegistrationFailedOnStartup { get; private set; }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    public HotkeyManager(ConfigService configService)
    {
        _configService = configService;
        _hook = HwndHook;

        var parameters = new HwndSourceParameters("DiktaHotkeyWindow")
        {
            Width = 0,
            Height = 0,
            PositionX = -100,
            PositionY = -100,
            WindowStyle = unchecked((int)0x80000000), // WS_POPUP
            ExtendedWindowStyle = 0x00000080,          // WS_EX_TOOLWINDOW
            ParentWindow = IntPtr.Zero
        };

        _source = new HwndSource(parameters);
        _source.AddHook(_hook);

        RegisterConfiguredHotkey();
    }

    private void RegisterConfiguredHotkey()
    {
        if (_source == null) return;

        uint modifiers = ParseModifiers(_configService.Config.HotkeyModifiers) | MOD_NOREPEAT;
        uint key = ParseKey(_configService.Config.HotkeyKey);

        if (!RegisterHotKey(_source.Handle, HOTKEY_ID, modifiers, key))
        {
            var error = Marshal.GetLastWin32Error();
            System.Diagnostics.Debug.WriteLine($"RegisterHotKey failed with error code: {error}");
            RegistrationFailedOnStartup = true;
            RegistrationFailed?.Invoke();
        }
        else
        {
            _registered = true;
        }
    }

    private static uint ParseModifiers(string modifierString)
    {
        uint mods = 0;
        var parts = modifierString.Split('+', StringSplitOptions.TrimEntries);
        foreach (var part in parts)
        {
            switch (part.ToLowerInvariant())
            {
                case "ctrl":
                case "control":
                    mods |= MOD_CONTROL;
                    break;
                case "shift":
                    mods |= MOD_SHIFT;
                    break;
                case "alt":
                    mods |= MOD_ALT;
                    break;
                case "win":
                    mods |= MOD_WIN;
                    break;
            }
        }
        return mods;
    }

    private static uint ParseKey(string key)
    {
        if (key.Length == 1 && char.IsLetterOrDigit(key[0]))
            return (uint)char.ToUpperInvariant(key[0]);

        return key.ToUpperInvariant() switch
        {
            "SPACE" => 0x20,
            "ENTER" => 0x0D,
            "TAB" => 0x09,
            "ESCAPE" => 0x1B,
            _ => (uint)char.ToUpperInvariant(key[0])
        };
    }

    /// <summary>
    /// Registers an application-defined window message (obtained via RegisterWindowMessage)
    /// so the existing HwndHook routes it to <see cref="ShowOnboardingRequested"/>.
    /// Call once from App.OnStartup after the first-instance check passes.
    /// </summary>
    public void RegisterExternalMessage(uint messageId)
    {
        _showOnboardingMsg = messageId;
    }

    public void ReregisterHotkey(string modifiers, string key)
    {
        if (_source == null) return;

        if (_registered)
        {
            UnregisterHotKey(_source.Handle, HOTKEY_ID);
            _registered = false;
        }

        uint newMods = ParseModifiers(modifiers) | MOD_NOREPEAT;
        uint newKey = ParseKey(key);

        if (!RegisterHotKey(_source.Handle, HOTKEY_ID, newMods, newKey))
        {
            throw new InvalidOperationException(
                $"Failed to register hotkey {modifiers}+{key}. It may be in use by another application.");
        }

        _registered = true;
    }

    private IntPtr HwndHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_HOTKEY && wParam.ToInt32() == HOTKEY_ID)
        {
            HotkeyPressed?.Invoke();
            handled = true;
        }
        else if (_showOnboardingMsg != 0 && (uint)msg == _showOnboardingMsg)
        {
            System.Diagnostics.Debug.WriteLine(
                "[Dikta] First instance received DiktaShowOnboarding via HwndHook.");
            ShowOnboardingRequested?.Invoke();
            handled = true;
        }
        return IntPtr.Zero;
    }

    public void Dispose()
    {
        if (_source != null)
        {
            if (_registered)
            {
                UnregisterHotKey(_source.Handle, HOTKEY_ID);
                _registered = false;
            }
            _source.RemoveHook(_hook);
            _source.Dispose();
            _source = null;
        }
    }
}
