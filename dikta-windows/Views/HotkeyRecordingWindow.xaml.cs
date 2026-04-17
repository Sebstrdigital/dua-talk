using System.Windows;
using System.Windows.Input;

namespace DiktaWindows.Views;

public partial class HotkeyRecordingWindow : Window
{
    // Internal capture state
    private ModifierKeys _mods = ModifierKeys.None;
    private Key _key = Key.None;

    // Public properties — populated just before DialogResult = true
    public string CapturedModifiers { get; private set; } = "";
    public string CapturedKey { get; private set; } = "";

    public HotkeyRecordingWindow()
    {
        InitializeComponent();
        this.PreviewKeyDown += OnPreviewKeyDown;
    }

    // ---------------------------------------------------------------------------
    // Key capture
    // ---------------------------------------------------------------------------

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        // Escape alone cancels
        if (e.Key == Key.Escape && Keyboard.Modifiers == ModifierKeys.None)
        {
            e.Handled = true;
            DialogResult = false;
            Close();
            return;
        }

        // Swallow all keys so they don't activate buttons
        e.Handled = true;

        var mods = Keyboard.Modifiers;

        // Alt combos: e.Key is Key.System; the real key is in e.SystemKey
        var actualKey = e.Key == Key.System ? e.SystemKey : e.Key;

        if (IsModifierOnly(actualKey))
        {
            // Show partial modifier hint but keep OK disabled
            UpdatePreview(mods, Key.None);
            return;
        }

        // Full combo captured
        _mods = mods;
        _key = actualKey;

        UpdatePreview(_mods, _key);

        if (_mods != ModifierKeys.None)
        {
            OkButton.IsEnabled = true;
            StatusLabel.Text = "";
        }
        else
        {
            OkButton.IsEnabled = false;
            StatusLabel.Text = "At least one modifier (Ctrl, Shift, Alt, Win) is required.";
        }
    }

    // ---------------------------------------------------------------------------
    // Button handlers
    // ---------------------------------------------------------------------------

    private void OkButton_Click(object sender, RoutedEventArgs e)
    {
        CapturedModifiers = FormatModifiersForConfig(_mods);
        CapturedKey = FormatKey(_key);
        DialogResult = true;
        Close();
    }

    private void CancelButton_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    private static bool IsModifierOnly(Key key) => key is
        Key.LeftCtrl or Key.RightCtrl or
        Key.LeftShift or Key.RightShift or
        Key.LeftAlt or Key.RightAlt or
        Key.LWin or Key.RWin or
        Key.System;

    /// <summary>Updates the preview label. Pass Key.None when only modifiers are held.</summary>
    private void UpdatePreview(ModifierKeys mods, Key key)
    {
        var parts = new System.Collections.Generic.List<string>();

        if (mods.HasFlag(ModifierKeys.Control)) parts.Add("Ctrl");
        if (mods.HasFlag(ModifierKeys.Shift))   parts.Add("Shift");
        if (mods.HasFlag(ModifierKeys.Alt))      parts.Add("Alt");
        if (mods.HasFlag(ModifierKeys.Windows))  parts.Add("Win");

        if (key != Key.None)
            parts.Add(FormatKey(key));

        PreviewLabel.Text = parts.Count > 0
            ? string.Join(" + ", parts)
            : "\u2014"; // em dash placeholder
    }

    /// <summary>Formats ModifierKeys as "Ctrl+Shift" — matches AppConfig.HotkeyModifiers format.</summary>
    private static string FormatModifiersForConfig(ModifierKeys mods)
    {
        var parts = new System.Collections.Generic.List<string>();
        if (mods.HasFlag(ModifierKeys.Control)) parts.Add("Ctrl");
        if (mods.HasFlag(ModifierKeys.Shift))   parts.Add("Shift");
        if (mods.HasFlag(ModifierKeys.Alt))      parts.Add("Alt");
        if (mods.HasFlag(ModifierKeys.Windows))  parts.Add("Win");
        return string.Join("+", parts);
    }

    /// <summary>Formats a Key as a display string, e.g. Key.D → "D", Key.F5 → "F5".</summary>
    private static string FormatKey(Key key)
    {
        // Key.ToString() gives "D", "F5", "Space", "Return", etc.
        return key.ToString();
    }
}
