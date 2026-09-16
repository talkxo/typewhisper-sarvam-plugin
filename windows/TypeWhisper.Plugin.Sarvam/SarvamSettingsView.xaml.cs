using System;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace TypeWhisper.Plugin.Sarvam;

public partial class SarvamSettingsView : UserControl
{
    private static readonly TimeSpan ApiKeySaveDebounce = TimeSpan.FromMilliseconds(300);

    private readonly SarvamPlugin _plugin;
    private CancellationTokenSource? _saveDebounceCts;
    private readonly bool _suppressEvents;

    public SarvamSettingsView(SarvamPlugin plugin)
    {
        _plugin = plugin;
        InitializeComponent();

        _suppressEvents = true;

        if (!string.IsNullOrEmpty(plugin.ApiKey))
        {
            ApiKeyBox.Password = plugin.ApiKey;
            StatusText.Text = "API key configured.";
            StatusText.Foreground = Brushes.Green;
        }

        SelectComboBoxItemByTag(ModeComboBox, plugin.SelectedMode);
        SelectComboBoxItemByTag(LanguageComboBox, plugin.SelectedLanguage);
        SelectComboBoxItemByTag(ModelComboBox, plugin.SelectedModelId ?? "saaras:v4");
        UpdateModeHelpText(plugin.SelectedMode);

        _suppressEvents = false;
    }

    private async void OnPasswordChanged(object sender, RoutedEventArgs e)
    {
        if (_suppressEvents) return;

        _saveDebounceCts?.Cancel();
        using var cts = new CancellationTokenSource();
        _saveDebounceCts = cts;

        try
        {
            await Task.Delay(ApiKeySaveDebounce, cts.Token);
            var key = ApiKeyBox.Password;
            await _plugin.SetApiKeyAsync(key);

            StatusText.Text = string.IsNullOrWhiteSpace(key) ? "" : "API key saved.";
            StatusText.Foreground = Brushes.Gray;
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            StatusText.Text = "Error: " + ex.Message;
            StatusText.Foreground = Brushes.Red;
        }
    }

    private async void OnTestClick(object sender, RoutedEventArgs e)
    {
        var key = ApiKeyBox.Password;
        if (string.IsNullOrWhiteSpace(key))
        {
            StatusText.Text = "Please enter an API key.";
            StatusText.Foreground = Brushes.Orange;
            return;
        }

        TestButton.IsEnabled = false;
        StatusText.Text = "Verifying with Sarvam API...";
        StatusText.Foreground = Brushes.Gray;

        try
        {
            var valid = await _plugin.ValidateApiKeyAsync(key);
            if (valid)
            {
                await _plugin.SetApiKeyAsync(key);
                StatusText.Text = "API key verified and active!";
                StatusText.Foreground = Brushes.Green;
            }
            else
            {
                StatusText.Text = "Invalid API key. Please check credentials.";
                StatusText.Foreground = Brushes.Red;
            }
        }
        catch (Exception ex)
        {
            StatusText.Text = "Verification error: " + ex.Message;
            StatusText.Foreground = Brushes.Red;
        }
        finally
        {
            TestButton.IsEnabled = true;
        }
    }

    private void OnModeSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressEvents) return;
        if (ModeComboBox.SelectedItem is ComboBoxItem item && item.Tag is string mode)
        {
            _plugin.SelectMode(mode);
            UpdateModeHelpText(mode);
        }
    }

    private void OnLanguageSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressEvents) return;
        if (LanguageComboBox.SelectedItem is ComboBoxItem item && item.Tag is string lang)
        {
            _plugin.SelectLanguage(lang);
        }
    }

    private void OnModelSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressEvents) return;
        if (ModelComboBox.SelectedItem is ComboBoxItem item && item.Tag is string modelId)
        {
            _plugin.SelectModel(modelId);
        }
    }

    private void UpdateModeHelpText(string mode)
    {
        ModeHelpText.Text = mode switch
        {
            "translit" => "Speaks Hindi/Indic → Writes in English alphabet (e.g. 'Mujhe flight book karni hai'). Perfect for WhatsApp & Slack.",
            "transcribe" => "Speaks Hindi/Indic → Writes in native Devanagari script (e.g. 'मुझे फ्लाइट बुक करनी है').",
            "translate" => "Speaks Hindi/Indic → Translates directly into English meaning (e.g. 'I need to book a flight').",
            "codemix" => "Speaks Hindi/Indic → Keeps English words in English letters, rest in Devanagari.",
            _ => ""
        };
    }

    private static void SelectComboBoxItemByTag(ComboBox comboBox, string? tag)
    {
        if (tag == null) return;
        foreach (var item in comboBox.Items)
        {
            if (item is ComboBoxItem cbi && string.Equals(cbi.Tag as string, tag, StringComparison.OrdinalIgnoreCase))
            {
                comboBox.SelectedItem = cbi;
                break;
            }
        }
    }
}
