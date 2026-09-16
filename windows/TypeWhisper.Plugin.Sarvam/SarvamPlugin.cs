using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using TypeWhisper.PluginSDK;
using TypeWhisper.PluginSDK.Models;

#if WINDOWS
using System.Windows.Controls;
#endif

namespace TypeWhisper.Plugin.Sarvam;

public sealed class SarvamPlugin : ITranscriptionEnginePlugin, ITypeWhisperPlugin
{
    public const string PluginIdConst = "com.typewhisper.sarvam";
    public const string PluginNameConst = "Sarvam AI (Saaras)";
    public const string PluginVersionConst = "1.0.1";
    private const string Endpoint = "https://api.sarvam.ai/speech-to-text";

    private readonly HttpClient _httpClient;
    private readonly SemaphoreSlim _apiKeyWriteLock = new(1, 1);

    private IPluginHostServices? _host;
    private string? _apiKey;
    private string _selectedModelId = "saaras:v4";
    private string _selectedMode = "translit";      // Default to Hinglish
    private string _selectedLanguage = "hi-IN";    // Default to Hindi for Hinglish

    public string PluginId => PluginIdConst;
    public string PluginName => PluginNameConst;
    public string PluginVersion => PluginVersionConst;

    public string ProviderId => PluginIdConst;
    public string ProviderDisplayName => PluginNameConst;

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_apiKey);

    public string? SelectedModelId => _selectedModelId;
    public string SelectedMode => _selectedMode;
    public string SelectedLanguage => _selectedLanguage;

    public bool SupportsTranslation => true;

    public IReadOnlyList<PluginModelInfo> TranscriptionModels { get; } =
    [
        new("saaras:v4", "Saaras v4 (Recommended - Latest transliteration)") { IsRecommended = true, LanguageCount = 22 },
        new("saaras:v3", "Saaras v3 (Fast)") { LanguageCount = 10 },
        new("saaras:v2.5", "Saaras v2.5 (Legacy)")
    ];

    public IReadOnlyList<string> SupportedLanguages { get; } =
    [
        "hi-IN", "bn-IN", "ta-IN", "te-IN", "kn-IN", "mr-IN", "gu-IN", "ml-IN", "pa-IN", "od-IN", "as-IN", "en-IN"
    ];

    internal string? ApiKey => _apiKey;
    internal IPluginHostServices? Host => _host;

    public SarvamPlugin()
    {
        _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(60) };
    }

    public async Task ActivateAsync(IPluginHostServices host)
    {
        _host = host;
        _apiKey = await host.LoadSecretAsync("api-key").ConfigureAwait(false);
        _selectedModelId = host.GetSetting<string>("selectedModel") ?? "saaras:v4";
        _selectedMode = host.GetSetting<string>("selectedMode") ?? "translit";
        _selectedLanguage = host.GetSetting<string>("selectedLanguage") ?? "hi-IN";
    }

    public Task DeactivateAsync()
    {
        return Task.CompletedTask;
    }

    public void SelectModel(string modelId)
    {
        _selectedModelId = modelId;
        _host?.SetSetting("selectedModel", modelId);
    }

    public void SelectMode(string mode)
    {
        _selectedMode = mode;
        _host?.SetSetting("selectedMode", mode);
    }

    public void SelectLanguage(string language)
    {
        _selectedLanguage = language;
        _host?.SetSetting("selectedLanguage", language);
    }

    public async Task SetApiKeyAsync(string? apiKey)
    {
        await _apiKeyWriteLock.WaitAsync().ConfigureAwait(false);
        try
        {
            var normalized = string.IsNullOrWhiteSpace(apiKey) ? null : apiKey.Trim();
            if (string.Equals(_apiKey, normalized, StringComparison.Ordinal))
                return;

            _apiKey = normalized;

            if (normalized is not null)
                await (_host?.StoreSecretAsync("api-key", normalized) ?? Task.CompletedTask).ConfigureAwait(false);
            else
                await (_host?.DeleteSecretAsync("api-key") ?? Task.CompletedTask).ConfigureAwait(false);
        }
        finally
        {
            _apiKeyWriteLock.Release();
        }

        _host?.NotifyCapabilitiesChanged();
    }

    public async Task<bool> ValidateApiKeyAsync(string apiKey, CancellationToken ct = default)
    {
        var normalized = string.IsNullOrWhiteSpace(apiKey) ? null : apiKey.Trim();
        if (normalized is null) return false;

        // Construct a silent 0.25s 16kHz mono WAV ping for validation
        byte[] pingWav = CreateSilentWav(16000, 0.25);

        using var content = new MultipartFormDataContent();
        var audioContent = new ByteArrayContent(pingWav);
        audioContent.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
        content.Add(audioContent, "file", "ping.wav");
        content.Add(new StringContent("saaras:v4"), "model");

        using var request = new HttpRequestMessage(HttpMethod.Post, Endpoint)
        {
            Content = content
        };
        request.Headers.Add("api-subscription-key", normalized);

        try
        {
            using var response = await _httpClient.SendAsync(request, ct).ConfigureAwait(false);
            if (response.IsSuccessStatusCode) return true;

            var code = (int)response.StatusCode;
            // 400 or 422 indicates valid key authorization reached the endpoint validator
            return code is 400 or 422;
        }
        catch
        {
            return false;
        }
    }

    public async Task<PluginTranscriptionResult> TranscribeAsync(
        byte[] wavAudio, string? language, bool translate, string? prompt, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(_apiKey))
            throw new InvalidOperationException("Sarvam AI API key is not configured. Please add your key in Settings.");

        var effectiveMode = translate ? "translate" : _selectedMode;
        var effectiveLanguage = ResolveEffectiveLanguage(language, effectiveMode);
        var model = _selectedModelId ?? "saaras:v4";

        using var content = new MultipartFormDataContent();
        var audioContent = new ByteArrayContent(wavAudio);
        audioContent.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
        content.Add(audioContent, "file", "audio.wav");
        content.Add(new StringContent(model), "model");
        content.Add(new StringContent(effectiveMode), "mode");

        if (!string.IsNullOrWhiteSpace(effectiveLanguage) && !effectiveLanguage.Equals("auto", StringComparison.OrdinalIgnoreCase))
        {
            content.Add(new StringContent(effectiveLanguage), "language_code");
        }

        using var request = new HttpRequestMessage(HttpMethod.Post, Endpoint)
        {
            Content = content
        };
        request.Headers.Add("api-subscription-key", _apiKey);

        using var response = await _httpClient.SendAsync(request, ct).ConfigureAwait(false);
        var responseBody = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Sarvam AI API Error ({(int)response.StatusCode}): {ExtractErrorMessage(responseBody)}");
        }

        using var doc = JsonDocument.Parse(responseBody);
        var root = doc.RootElement;
        var transcript = "";
        if (root.TryGetProperty("transcript", out var tProp) && tProp.ValueKind == JsonValueKind.String)
        {
            transcript = tProp.GetString() ?? "";
        }
        else if (root.TryGetProperty("text", out var textProp) && textProp.ValueKind == JsonValueKind.String)
        {
            transcript = textProp.GetString() ?? "";
        }

        var detectedLang = effectiveLanguage;
        if (root.TryGetProperty("language_code", out var langProp) && langProp.ValueKind == JsonValueKind.String)
        {
            detectedLang = langProp.GetString();
        }

        return new PluginTranscriptionResult(transcript.Trim(), detectedLang ?? "unknown", 0.0);
    }

    private string ResolveEffectiveLanguage(string? hostLanguage, string mode)
    {
        if (_selectedLanguage != "follow-typewhisper")
        {
            return _selectedLanguage;
        }

        if (string.IsNullOrWhiteSpace(hostLanguage) || hostLanguage.Equals("auto", StringComparison.OrdinalIgnoreCase))
        {
            return "unknown";
        }

        var lower = hostLanguage.Trim().ToLowerInvariant();
        if (mode == "translit" && (lower == "en" || lower == "en-in"))
        {
            return "hi-IN";
        }

        return lower switch
        {
            "hi" => "hi-IN",
            "bn" => "bn-IN",
            "ta" => "ta-IN",
            "te" => "te-IN",
            "kn" => "kn-IN",
            "mr" => "mr-IN",
            "gu" => "gu-IN",
            "ml" => "ml-IN",
            "pa" => "pa-IN",
            "od" or "or" => "od-IN",
            "as" => "as-IN",
            "en" => "en-IN",
            _ => hostLanguage
        };
    }

    private static string ExtractErrorMessage(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.TryGetProperty("error", out var err))
            {
                if (err.ValueKind == JsonValueKind.String) return err.GetString() ?? json;
                if (err.TryGetProperty("message", out var msg)) return msg.GetString() ?? json;
            }
            if (doc.RootElement.TryGetProperty("message", out var m)) return m.GetString() ?? json;
            if (doc.RootElement.TryGetProperty("detail", out var d)) return d.GetString() ?? json;
        }
        catch { }
        return json;
    }

    private static byte[] CreateSilentWav(int sampleRate, double durationSeconds)
    {
        int numSamples = (int)(sampleRate * durationSeconds);
        int subchunk2Size = numSamples * 2;
        int chunkSize = 36 + subchunk2Size;

        byte[] wav = new byte[44 + subchunk2Size];
        using var ms = new MemoryStream(wav);
        using var bw = new BinaryWriter(ms);

        bw.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));
        bw.Write(chunkSize);
        bw.Write(System.Text.Encoding.ASCII.GetBytes("WAVE"));
        bw.Write(System.Text.Encoding.ASCII.GetBytes("fmt "));
        bw.Write(16);
        bw.Write((short)1);
        bw.Write((short)1);
        bw.Write(sampleRate);
        bw.Write(sampleRate * 2);
        bw.Write((short)2);
        bw.Write((short)16);
        bw.Write(System.Text.Encoding.ASCII.GetBytes("data"));
        bw.Write(subchunk2Size);

        return wav;
    }

#if WINDOWS
    public UserControl? CreateSettingsView() => new SarvamSettingsView(this);
#endif

    public void Dispose()
    {
        _httpClient.Dispose();
        _apiKeyWriteLock.Dispose();
    }
}
