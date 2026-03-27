using System.Windows;
using System.Windows.Controls;
using DiktaWindows.Services;

namespace DiktaWindows.Views;

public partial class SettingsWindow : Window
{
    private readonly ConfigService _configService;
    private readonly HotkeyManager _hotkeyManager;

    public SettingsWindow(ConfigService configService, HotkeyManager hotkeyManager)
    {
        InitializeComponent();
        _configService = configService;
        _hotkeyManager = hotkeyManager;

        PopulateKeyCombo();
        LoadCurrentHotkey();
    }

    private void PopulateKeyCombo()
    {
        for (char c = 'A'; c <= 'Z'; c++)
            KeyCombo.Items.Add(c.ToString());
        for (char c = '0'; c <= '9'; c++)
            KeyCombo.Items.Add(c.ToString());
    }

    private void LoadCurrentHotkey()
    {
        var currentMods = _configService.Config.HotkeyModifiers
            .Split('+', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .Select(m => m.ToLowerInvariant())
            .ToHashSet();

        foreach (ListBoxItem item in ModifiersList.Items)
        {
            if (currentMods.Contains(item.Content.ToString()!.ToLowerInvariant()))
                ModifiersList.SelectedItems.Add(item);
        }

        var currentKey = _configService.Config.HotkeyKey.ToUpperInvariant();
        KeyCombo.SelectedItem = currentKey;
        if (KeyCombo.SelectedItem == null && KeyCombo.Items.Count > 0)
            KeyCombo.SelectedIndex = 0;
    }

    private void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        var selectedMods = ModifiersList.SelectedItems
            .Cast<ListBoxItem>()
            .Select(i => i.Content.ToString()!)
            .ToList();

        var modifierString = selectedMods.Count > 0
            ? string.Join("+", selectedMods)
            : string.Empty;

        var key = KeyCombo.SelectedItem?.ToString() ?? _configService.Config.HotkeyKey;

        _hotkeyManager.ReregisterHotkey(modifierString, key);
        _configService.Config.HotkeyModifiers = modifierString;
        _configService.Config.HotkeyKey = key;
        _configService.Save();

        Close();
    }

    private void CancelButton_Click(object sender, RoutedEventArgs e)
    {
        Close();
    }
}
