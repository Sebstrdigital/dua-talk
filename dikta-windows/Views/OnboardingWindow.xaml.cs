using System.Diagnostics;
using System.Reflection;
using System.Windows;
using System.Windows.Media;
using NAudio.Wave;
using DiktaWindows.Services;

namespace DiktaWindows.Views;

public partial class OnboardingWindow : Window
{
    private readonly ConfigService _configService;

    public OnboardingWindow(ConfigService configService)
    {
        InitializeComponent();
        _configService = configService;

        LoadVersion();
        LoadHotkey();
        RefreshMicStatus();

        // "Don't show on startup" checked  ↔  ShowOnStartup = false
        DontShowCheckBox.IsChecked = !_configService.Config.ShowOnStartup;

        Closing += OnWindowClosing;
        Activated += OnWindowActivated;
    }

    private void OnWindowClosing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        _configService.Config.ShowOnStartup = !(DontShowCheckBox.IsChecked ?? false);
        _configService.Save();
    }

    private void OnWindowActivated(object? sender, EventArgs e)
    {
        RefreshMicStatus();
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

    private void RefreshMicStatus()
    {
        int deviceCount = WaveIn.DeviceCount;

        if (deviceCount == 0)
        {
            MicStatusLabel.Text = "Not granted";
            MicStatusLabel.Foreground = Brushes.Red;
            GrantButton.Visibility = Visibility.Visible;
        }
        else
        {
            MicStatusLabel.Text = "Granted";
            MicStatusLabel.Foreground = Brushes.Green;
            GrantButton.Visibility = Visibility.Collapsed;
        }
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
