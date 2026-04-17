using System.Diagnostics;
using System.Reflection;
using System.Windows;
using System.Windows.Media;
using DiktaWindows.Services;

namespace DiktaWindows.Views;

public partial class OnboardingWindow : Window
{
    private readonly ConfigService _configService;
    private bool _dontShowOnStartup;

    public OnboardingWindow(ConfigService configService)
    {
        InitializeComponent();
        _configService = configService;

        LoadVersion();
        LoadHotkey();
        LoadMicStatus();
    }

    private void LoadVersion()
    {
        var version = Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "unknown";
        VersionLabel.Text = $"v{version}";
    }

    private void LoadHotkey()
    {
        var modifiers = _configService.Config.HotkeyModifiers;
        var key = _configService.Config.HotkeyKey;

        // Split on "+" and rejoin with " + " for display (e.g. "Ctrl+Shift" → "Ctrl + Shift")
        var parts = modifiers
            .Split('+', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .ToList();

        if (!string.IsNullOrEmpty(key))
            parts.Add(key);

        HotkeyLabel.Text = string.Join(" + ", parts);
    }

    private void LoadMicStatus()
    {
        // Placeholder — US-007 will add refresh logic and the Activated handler.
        MicStatusLabel.Text = "\u2014";
        GrantButton.Visibility = Visibility.Collapsed;
    }

    private void GrantButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo("ms-settings:privacy-microphone")
            {
                UseShellExecute = true
            });
        }
        catch
        {
            // Best-effort: swallow all exceptions — settings URI may not be available.
        }
    }
}
