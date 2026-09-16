import Foundation
import AppKit
import SwiftUI
import os
import TypeWhisperPluginSDK

// MARK: - Plugin Entry Point

@objc(SarvamPlugin)
final class SarvamPlugin: NSObject, TranscriptionEnginePlugin, @unchecked Sendable {
    static let pluginId = "com.typewhisper.sarvam"
    static let pluginName = "Sarvam AI (Saaras)"

    private static let endpoint = "https://api.sarvam.ai/speech-to-text"
    private static let defaultModel = "saaras:v4"
    private static let defaultMode = "translit"       // Default to Hinglish / Roman script
    private static let defaultLanguage = "hi-IN"      // Default to Hindi for Hinglish transliteration

    private let state = SarvamPluginState()
    private let logger = Logger(subsystem: "com.typewhisper.sarvam", category: "Plugin")

    required override init() {
        super.init()
    }

    func activate(host: HostServices) {
        state.activate(
            host: host,
            apiKey: host.loadSecret(key: "api-key"),
            selectedModelId: host.userDefault(forKey: "selectedModel") as? String ?? Self.defaultModel,
            selectedMode: host.userDefault(forKey: "selectedMode") as? String ?? Self.defaultMode,
            selectedLanguage: host.userDefault(forKey: "selectedLanguage") as? String ?? Self.defaultLanguage
        )
    }

    func deactivate() {
        state.deactivate()
    }

    // MARK: - TranscriptionEnginePlugin

    var providerId: String { "sarvam-saaras" }
    var providerDisplayName: String { "Sarvam AI (Saaras)" }

    var isConfigured: Bool {
        guard let key = state.snapshot().apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var transcriptionModels: [PluginModelInfo] {
        [
            PluginModelInfo(
                id: "saaras:v4",
                displayName: "Saaras v4 (Recommended - Latest)",
                sizeDescription: "22 Indic Languages + English",
                languageCount: 23
            ),
            PluginModelInfo(
                id: "saaras:v3",
                displayName: "Saaras v3",
                sizeDescription: "High Accuracy / Fast",
                languageCount: 11
            ),
            PluginModelInfo(
                id: "saaras:v2.5",
                displayName: "Saaras v2.5 (Legacy)",
                sizeDescription: "Standard",
                languageCount: 11
            ),
        ]
    }

    var selectedModelId: String? {
        state.snapshot().selectedModelId ?? Self.defaultModel
    }

    func selectModel(_ modelId: String) {
        state.currentHost()?.setUserDefault(modelId, forKey: "selectedModel")
        state.updateSelectedModelId(modelId)
    }

    var selectedMode: String {
        state.snapshot().selectedMode ?? Self.defaultMode
    }

    func selectMode(_ mode: String) {
        state.currentHost()?.setUserDefault(mode, forKey: "selectedMode")
        state.updateSelectedMode(mode)
    }

    var selectedLanguage: String {
        state.snapshot().selectedLanguage ?? Self.defaultLanguage
    }

    func selectLanguage(_ lang: String) {
        state.currentHost()?.setUserDefault(lang, forKey: "selectedLanguage")
        state.updateSelectedLanguage(lang)
    }

    var supportsTranslation: Bool { true }

    // Supported ISO language codes advertised to TypeWhisper
    static let languageMap: [String: String] = [
        "hi": "hi-IN",
        "bn": "bn-IN",
        "ta": "ta-IN",
        "te": "te-IN",
        "kn": "kn-IN",
        "mr": "mr-IN",
        "gu": "gu-IN",
        "ml": "ml-IN",
        "pa": "pa-IN",
        "od": "od-IN",
        "or": "od-IN",
        "as": "as-IN",
        "en": "en-IN",
    ]

    var supportedLanguages: [String] {
        Array(Self.languageMap.keys)
    }

    func resolveEffectiveLanguage(hostLanguage: String?, mode: String) -> String {
        let configured = selectedLanguage

        // If user set a specific language in plugin settings (e.g. hi-IN or unknown), use it
        if configured != "follow-typewhisper" {
            return configured
        }

        // Otherwise, resolve from TypeWhisper host
        guard let hostLanguage = hostLanguage?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !hostLanguage.isEmpty,
              hostLanguage != "auto" else {
            return "unknown"
        }

        let mapped = Self.languageMap[hostLanguage] ?? hostLanguage

        // If user wants transliteration (Hinglish) but TypeWhisper passes generic "en" / "en-IN",
        // don't tell Sarvam the speaker is speaking pure English (which breaks Hindi transliteration)
        if mode == "translit" && mapped == "en-IN" {
            return "hi-IN"
        }

        return mapped
    }

    // MARK: - Transcription Execution

    func transcribe(
        audio: AudioData,
        language: String?,
        translate: Bool,
        prompt: String?
    ) async throws -> PluginTranscriptionResult {
        let snapshot = state.snapshot()
        guard let apiKey = snapshot.apiKey, !apiKey.isEmpty else {
            throw PluginTranscriptionError.notConfigured
        }

        let model = snapshot.selectedModelId ?? Self.defaultModel
        let configuredMode = snapshot.selectedMode ?? Self.defaultMode

        // Determine effective mode:
        // If the user picked "translit" (Hinglish), keep "translit" so dictation writes Hinglish.
        // If the user picked another mode and TypeWhisper requested translation, use "translate".
        let effectiveMode: String
        if translate && configuredMode != "translit" {
            effectiveMode = "translate"
        } else {
            effectiveMode = configuredMode
        }

        let resolvedLang = resolveEffectiveLanguage(hostLanguage: language, mode: effectiveMode)

        let request = try Self.makeMultipartRequest(
            endpoint: Self.endpoint,
            wavData: audio.wavData,
            apiKey: apiKey,
            model: model,
            mode: effectiveMode,
            languageCode: resolvedLang,
            prompt: prompt
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PluginTranscriptionError.networkError("Invalid HTTP response from Sarvam AI")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw PluginTranscriptionError.invalidApiKey
        case 429:
            throw PluginTranscriptionError.rateLimited
        case 413:
            throw PluginTranscriptionError.fileTooLarge
        default:
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw PluginTranscriptionError.apiError("HTTP \(httpResponse.statusCode): \(errorText)")
        }

        return try Self.parseResponse(data)
    }

    // MARK: - HTTP Request Helper

    static func makeMultipartRequest(
        endpoint: String,
        wavData: Data,
        apiKey: String,
        model: String,
        mode: String,
        languageCode: String,
        prompt: String?
    ) throws -> URLRequest {
        guard let url = URL(string: endpoint) else {
            throw PluginTranscriptionError.apiError("Invalid Sarvam endpoint URL")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "api-subscription-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var body = Data()

        // 1. Audio file field
        body.appendMultipartField(boundary: boundary, name: "file", filename: "audio.wav", mimeType: "audio/wav", data: wavData)

        // 2. Model parameter
        body.appendFormField(boundary: boundary, name: "model", value: model)

        // 3. Mode parameter (translit, transcribe, translate, codemix, verbatim)
        body.appendFormField(boundary: boundary, name: "mode", value: mode)

        // 4. Language code parameter (always provide language_code to trigger proper handling / detection)
        body.appendFormField(boundary: boundary, name: "language_code", value: languageCode)

        // 5. Optional prompt parameter
        if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body.appendFormField(boundary: boundary, name: "prompt", value: prompt)
        }

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return request
    }

    private struct SarvamSTTResponse: Decodable {
        let transcript: String?
        let language_code: String?
        let request_id: String?
    }

    static func parseResponse(_ data: Data) throws -> PluginTranscriptionResult {
        if let decoded = try? JSONDecoder().decode(SarvamSTTResponse.self, from: data),
           let transcript = decoded.transcript {
            return PluginTranscriptionResult(
                text: transcript.trimmingCharacters(in: .whitespacesAndNewlines),
                detectedLanguage: decoded.language_code
            )
        }

        // Fallback generic JSON parse
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let transcript = json["transcript"] as? String {
                let lang = json["language_code"] as? String
                return PluginTranscriptionResult(
                    text: transcript.trimmingCharacters(in: .whitespacesAndNewlines),
                    detectedLanguage: lang
                )
            }
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                throw PluginTranscriptionError.apiError(message)
            }
            if let detail = json["detail"] as? String {
                throw PluginTranscriptionError.apiError(detail)
            }
        }

        throw PluginTranscriptionError.apiError("Failed to parse Sarvam AI response")
    }

    // MARK: - Validation & Settings

    enum ValidationResult: Equatable {
        case valid
        case invalidKey
        case error(String)
    }

    func validateApiKey(_ key: String) async -> ValidationResult {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return .invalidKey }

        // Generate 0.25s silent WAV
        let silentSamples = [Float](repeating: 0, count: 4000)
        let testWav = PluginWavEncoder.encode(silentSamples, sampleRate: 16000)

        do {
            let request = try Self.makeMultipartRequest(
                endpoint: Self.endpoint,
                wavData: testWav,
                apiKey: trimmedKey,
                model: Self.defaultModel,
                mode: "transcribe",
                languageCode: "en-IN",
                prompt: nil
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("Invalid server response")
            }

            if httpResponse.statusCode == 200 {
                return .valid
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return .invalidKey
            } else {
                let msg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                return .error(msg)
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }

    var apiKeyForSettings: String? {
        state.snapshot().apiKey
    }

    func setApiKey(_ key: String) throws {
        guard let host = state.currentHost() else { return }
        try host.storeSecret(key: "api-key", value: key)
        state.updateApiKey(key)
        host.notifyCapabilitiesChanged()
    }

    func removeApiKey() throws {
        guard let host = state.currentHost() else { return }
        try host.storeSecret(key: "api-key", value: "")
        state.updateApiKey(nil)
        host.notifyCapabilitiesChanged()
    }

    var settingsView: AnyView? {
        AnyView(SarvamSettingsView(plugin: self))
    }
}

// MARK: - Thread-Safe State

private struct SarvamPluginStateSnapshot: Sendable {
    let apiKey: String?
    let selectedModelId: String?
    let selectedMode: String?
    let selectedLanguage: String?
}

private final class SarvamPluginState: @unchecked Sendable {
    private let lock = NSLock()
    private var host: HostServices?
    private var apiKey: String?
    private var selectedModelId: String?
    private var selectedMode: String?
    private var selectedLanguage: String?

    func activate(
        host: HostServices,
        apiKey: String?,
        selectedModelId: String?,
        selectedMode: String?,
        selectedLanguage: String?
    ) {
        lock.withLock {
            self.host = host
            self.apiKey = apiKey
            self.selectedModelId = selectedModelId
            self.selectedMode = selectedMode
            self.selectedLanguage = selectedLanguage
        }
    }

    func deactivate() {
        lock.withLock {
            host = nil
        }
    }

    func currentHost() -> HostServices? {
        lock.withLock { host }
    }

    func snapshot() -> SarvamPluginStateSnapshot {
        lock.withLock {
            SarvamPluginStateSnapshot(
                apiKey: apiKey,
                selectedModelId: selectedModelId,
                selectedMode: selectedMode,
                selectedLanguage: selectedLanguage
            )
        }
    }

    func updateApiKey(_ key: String?) {
        lock.withLock {
            self.apiKey = key
        }
    }

    func updateSelectedModelId(_ modelId: String) {
        lock.withLock {
            self.selectedModelId = modelId
        }
    }

    func updateSelectedMode(_ mode: String) {
        lock.withLock {
            self.selectedMode = mode
        }
    }

    func updateSelectedLanguage(_ lang: String) {
        lock.withLock {
            self.selectedLanguage = lang
        }
    }
}

// MARK: - Data Multipart Extension

private extension Data {
    mutating func appendFormField(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartField(
        boundary: String,
        name: String,
        filename: String,
        mimeType: String,
        data: Data
    ) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}

// MARK: - Settings View

private struct SarvamSettingsView: View {
    let plugin: SarvamPlugin

    @State private var apiKeyInput = ""
    @State private var showApiKey = false
    @State private var isValidating = false
    @State private var validationResult: SarvamPlugin.ValidationResult?
    @State private var selectedModel: String = "saaras:v4"
    @State private var selectedMode: String = "translit"
    @State private var selectedLanguage: String = "hi-IN"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Sarvam AI (Saaras STT)")
                    .font(.headline)
                Text("State-of-the-art speech recognition & transliteration for Hindi, Hinglish, and 20+ Indic languages.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // API Key Section
            VStack(alignment: .leading, spacing: 8) {
                Text("API Subscription Key")
                    .font(.subheadline.bold())

                HStack(spacing: 8) {
                    if showApiKey {
                        TextField("Enter Sarvam API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("Enter Sarvam API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showApiKey.toggle()
                    } label: {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)

                    if plugin.isConfigured {
                        Button("Remove") {
                            apiKeyInput = ""
                            validationResult = nil
                            try? plugin.removeApiKey()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    } else {
                        Button("Save & Verify") {
                            saveAndValidate()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
                    }
                }

                if isValidating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Verifying with Sarvam API...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                } else if let result = validationResult {
                    HStack(spacing: 6) {
                        switch result {
                        case .valid:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API Key verified and active.")
                                .font(.caption)
                                .foregroundStyle(.green)
                        case .invalidKey:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Invalid API key. Please check your credentials.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        case .error(let msg):
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Validation notice: \(msg)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.top, 2)
                }

                Link("Get your API key at dashboard.sarvam.ai →", destination: URL(string: "https://dashboard.sarvam.ai")!)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.top, 2)
            }

            Divider()

            // Output Mode (The most important setting for Hinglish vs Hindi script)
            VStack(alignment: .leading, spacing: 8) {
                Text("Output Format / Style")
                    .font(.subheadline.bold())

                Picker("Output Format", selection: $selectedMode) {
                    Text("Hinglish / Roman Script (Texting Style)").tag("translit")
                    Text("Native Devanagari Script (e.g. हिंदी)").tag("transcribe")
                    Text("Translate to English Meaning").tag("translate")
                    Text("CodeMix (Devanagari + English Words)").tag("codemix")
                }
                .pickerStyle(.menu)
                .onChange(of: selectedMode) { _, newValue in
                    plugin.selectMode(newValue)
                }

                // Helpful description for the selected mode
                Group {
                    switch selectedMode {
                    case "translit":
                        Label("Speaks Hindi/Indic → Writes in English alphabet (e.g. 'Mujhe kal meeting schedule karni hai'). Perfect for messaging/chat.", systemImage: "textformat.abc")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    case "transcribe":
                        Label("Speaks Hindi/Indic → Writes in native Devanagari script (e.g. 'मुझे कल मीटिंग शेड्यूल करनी है').", systemImage: "character")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case "translate":
                        Label("Speaks Hindi/Indic → Translates the meaning directly into English (e.g. 'I need to schedule a meeting tomorrow').", systemImage: "globe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case "codemix":
                        Label("Speaks Hindi/Indic → Keeps English words in English letters, rest in Devanagari (e.g. 'मुझे कल meeting schedule करनी है').", systemImage: "slider.horizontal.2.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    default:
                        EmptyView()
                    }
                }
                .padding(.top, 2)
            }

            Divider()

            // Spoken Language Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Spoken Language")
                    .font(.subheadline.bold())

                Picker("Spoken Language", selection: $selectedLanguage) {
                    Text("Hindi (hi-IN) - Recommended for Hinglish").tag("hi-IN")
                    Text("Auto-Detect (unknown)").tag("unknown")
                    Text("Indian English (en-IN)").tag("en-IN")
                    Text("Bengali (bn-IN)").tag("bn-IN")
                    Text("Tamil (ta-IN)").tag("ta-IN")
                    Text("Telugu (te-IN)").tag("te-IN")
                    Text("Marathi (mr-IN)").tag("mr-IN")
                    Text("Gujarati (gu-IN)").tag("gu-IN")
                    Text("Kannada (kn-IN)").tag("kn-IN")
                    Text("Malayalam (ml-IN)").tag("ml-IN")
                    Text("Punjabi (pa-IN)").tag("pa-IN")
                    Text("Follow TypeWhisper Language").tag("follow-typewhisper")
                }
                .pickerStyle(.menu)
                .onChange(of: selectedLanguage) { _, newValue in
                    plugin.selectLanguage(newValue)
                }

                Text("Locking to 'Hindi (hi-IN)' gives the highest accuracy when dictating conversational Hindi/Hinglish.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Model Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Model Selection")
                    .font(.subheadline.bold())

                Picker("Model", selection: $selectedModel) {
                    Text("Saaras v4 (Recommended - Latest transliteration)").tag("saaras:v4")
                    Text("Saaras v3 (Fast)").tag("saaras:v3")
                    Text("Saaras v2.5 (Legacy)").tag("saaras:v2.5")
                }
                .pickerStyle(.menu)
                .onChange(of: selectedModel) { _, newValue in
                    plugin.selectModel(newValue)
                }
            }

            Divider()

            // Credits, Origin & Trademarks
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("About & Attribution")
                        .font(.subheadline.bold())
                }

                // TalkXO team credit
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text("Crafted with ❤️ by the good folks at")
                            .font(.callout.weight(.medium))
                        Text("TalkXO")
                            .font(.callout.bold())
                        Text("in India 🇮🇳")
                            .font(.callout.weight(.medium))
                    }
                    Text("Originally developed as an internal tool for our team at TalkXO, and shared openly with the community as an enthusiastic enabler for Indic voice workflows.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.08))
                }

                // Sarvam AI attribution & legal disclaimer
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Trademarks & Independent Enabler Disclaimer")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }

                    Text("Sarvam AI and the Saaras model family (Saaras v4, v3, v2.5) are trademarks and intellectual property of Sarvam AI Technologies Pvt. Ltd.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("This plugin is an independent, community-driven enabler. It is not an official product of, nor endorsed, sponsored, or affiliated with Sarvam AI. We hold no claim or rights over the Sarvam name, trademarks, or proprietary speech models. All transcription requests are securely processed directly against Sarvam AI's official REST API using your personal API key under your own agreement with Sarvam AI.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }

                HStack(spacing: 16) {
                    Link("TalkXO Website →", destination: URL(string: "https://hello.talkxo.com")!)
                    Link("Sarvam AI Website →", destination: URL(string: "https://www.sarvam.ai")!)
                    Link("Sarvam API Docs →", destination: URL(string: "https://docs.sarvam.ai/api/api-guides-tutorials/speech-to-text/rest-api")!)
                }
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .onAppear {
            if let existingKey = plugin.apiKeyForSettings, !existingKey.isEmpty {
                apiKeyInput = existingKey
                validationResult = .valid
            }
            selectedModel = plugin.selectedModelId ?? "saaras:v4"
            selectedMode = plugin.selectedMode
            selectedLanguage = plugin.selectedLanguage
        }
    }

    private func saveAndValidate() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isValidating = true
        validationResult = nil

        Task {
            let result = await plugin.validateApiKey(trimmed)
            await MainActor.run {
                isValidating = false
                validationResult = result
                if result == .valid {
                    try? plugin.setApiKey(trimmed)
                }
            }
        }
    }
}
