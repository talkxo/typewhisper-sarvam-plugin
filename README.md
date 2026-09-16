# Sarvam AI (Saaras) Plugin for TypeWhisper 🇮🇳 🎙️

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B%20%28Sonoma%2FSequoia%29-blue?logo=apple)](https://apple.com)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)](https://swift.org)
[![TypeWhisper 1.6.0+](https://img.shields.io/badge/TypeWhisper-1.6.0%2B-purple)](https://typewhisper.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Built by TalkXO](https://img.shields.io/badge/Crafted%20by-TalkXO-green)](https://hello.talkxo.com)

Supercharge macOS voice dictation with **Indic languages**, **chat-style Hinglish transliteration**, and **real-time English translation** powered by [Sarvam AI](https://www.sarvam.ai)'s state-of-the-art **Saaras** speech models (`saaras:v4` and `saaras:v3`).

Originally crafted by the team at [**TalkXO**](https://hello.talkxo.com) for internal team productivity, and shared freely as an open community enabler.

---

## 🚀 What Can You Do With It? (Beginner Overview)

### 1. 💬 Chat in Hinglish (Latin / Roman Script)
Speak naturally in Hindi, and have your Mac type it out in English/Latin letters — exactly how people text on WhatsApp, Slack, and Instagram.
- **You speak**: *"Bhai kal subah meeting kitne baje hai?"*
- **It types**: `Bhai kal subah meeting kitne baje hai?` *(No manual typing, no awkward formal English translation, no Devanagari script)*.

### 2. 🇮🇳 Native Indic Scripts (22+ Languages)
Dictate in native scripts with industry-leading accuracy across:
- **Hindi** (`hi-IN`), **Bengali** (`bn-IN`), **Tamil** (`ta-IN`), **Telugu** (`te-IN`), **Marathi** (`mr-IN`), **Gujarati** (`gu-IN`), **Kannada** (`kn-IN`), **Malayalam** (`ml-IN`), **Punjabi** (`pa-IN`), **Odia** (`od-IN`), **Assamese** (`as-IN`), and more.
- **You speak**: *"आज का मौसम बहुत अच्छा है"*
- **It types**: `आज का मौसम बहुत अच्छा है`

### 3. 🌐 Instant Translation to English
Speak in your native language, and TypeWhisper will immediately write the meaning in fluent English.
- **You speak**: *"Mujhe kal subah flight book karni hai Delhi ke liye"*
- **It types**: `I need to book a flight to Delhi tomorrow morning.`

### 4. 🔀 CodeMix Mode
Keeps technical or everyday English words in English letters while writing Hindi words in native Devanagari.
- **You speak**: *"Mujhe document review karna hai"*
- **It types**: `मुझे document review करना है`

### 5. 🎯 App-Specific Switching (The Magic Trick!)
You don't have to give up your default transcription engine! Using TypeWhisper **Workflows**, you can configure Sarvam Hinglish to activate **only when you're in WhatsApp, Slack, or Telegram**, while keeping standard Whisper for everything else (Notes, Google Docs, VS Code, Browser).

---

## 📊 Sample Outputs by Mode

| You Say (Spoken Audio) | Selected Mode | What Gets Typed |
| :--- | :--- | :--- |
| *"Kal presentation ke liye slides ready kar lena"* | **Hinglish / Roman Script** *(Translit)* | `Kal presentation ke liye slides ready kar lena` |
| *"Kal presentation ke liye slides ready kar lena"* | **Native Script** *(Transcribe)* | `कल प्रेजेंटेशन के लिए स्लाइड्स रेडी कर लेना` |
| *"Kal presentation ke liye slides ready kar lena"* | **Translate to English** | `Please prepare the slides for tomorrow's presentation.` |
| *"Kal presentation ke liye slides ready kar lena"* | **CodeMix** | `कल presentation के लिए slides ready कर लेना` |

---

## ⚡ Quick Start: Beginner Guide (2 Minutes)

### Step 1: Download & Install
1. Download **`SarvamPlugin.zip`** from the [Releases](https://github.com/talkxo/typewhisper-sarvam-plugin/releases) section (or extract from this repo).
2. Double-click `SarvamPlugin.zip` to extract **`SarvamPlugin.bundle`**.
3. Move `SarvamPlugin.bundle` to your TypeWhisper plugins folder:
   ```bash
   mkdir -p ~/Library/Application\ Support/TypeWhisper/Plugins
   cp -R SarvamPlugin.bundle ~/Library/Application\ Support/TypeWhisper/Plugins/
   ```
4. **Restart TypeWhisper** (quit completely and reopen).

---

### Step 2: Add your Sarvam API Key
1. Get a free API key from [dashboard.sarvam.ai](https://dashboard.sarvam.ai).
2. In TypeWhisper, open **Settings** (`Cmd + ,`).
3. In the sidebar, go to **Integrations** → click **Installed** at the top.
4. Locate **Sarvam AI (Saaras)** and click **Settings**.
5. Paste your API Key and click **Save & Verify** *(you'll see a green checkmark once verified)*.

---

### Step 3: Configure for Hinglish
In the plugin settings window:
1. **Output Format / Style**: Select **Hinglish / Roman Script (Texting Style)**.
2. **Spoken Language**: Keep on **Hindi (hi-IN) - Recommended for Hinglish**.
3. **Model**: Select **Saaras v4** *(recommended for the best Indic accuracy)*.

Now hit your TypeWhisper global dictation hotkey anywhere on your Mac and start speaking!

---

## 🪄 Pro Setup: Use Sarvam ONLY in Messaging Apps

Want Sarvam AI's Hinglish to automatically kick in when you're texting on WhatsApp or Slack, but keep standard Whisper everywhere else? Set this up in 30 seconds:

1. Open **TypeWhisper Settings** (`Cmd + ,`) → Click **Workflows** in the sidebar.
2. Click **Create First Workflow** (or the **`+`** button in the top right).
3. Select the **Dictation Only** template card.
4. Configure the workflow:
   - **Name**: `Hinglish Messaging`
   - **Transcription Engine**: Change from *Use Global Engine* to **Sarvam AI (Saaras)**.
   - **Model**: Select `Saaras v4`.
5. Under **Trigger**:
   - Set to **Automatic**.
   - Check the **App** toggle.
   - Click **Add App** and select your target apps (e.g. **WhatsApp**, **Slack**, **Messages**, **Telegram**).
6. Click **Save**.

🎉 **That's it!** Whenever WhatsApp or Slack is active, TypeWhisper routes your voice to Sarvam AI. In all other apps, your normal default engine runs automatically.

---

## 🛠️ Advanced User & Developer Guide

### Architecture

```
[ Microphone Audio ]
         │
         ▼
[ TypeWhisper Core ] ── (16kHz Mono WAV) ──► [ SarvamPlugin.bundle ]
                                                        │
                                                        ▼ (Multipart POST)
                                         [ https://api.sarvam.ai/speech-to-text ]
                                                        │
                                                        ▼ (JSON Response)
[ Active App (Text Field) ] ◄── (Pasted Text) ◄── [ Plugin Output ]
```

- **Zero-Transcoding Audio Pipeline**: TypeWhisper records 16kHz mono audio and provides pre-formatted WAV buffers via `AudioData.wavData`. The plugin streams this directly as `multipart/form-data` with zero re-encoding latency.
- **Secure Keychain Storage**: API keys are securely persisted in the macOS Keychain using TypeWhisper's sandboxed `HostServices.storeSecret` API (`api-key`).
- **Dynamic Linker & RPATH**: The plugin dylib is linked with `@executable_path/../Frameworks` to locate `TypeWhisperPluginSDK.framework` directly from the host TypeWhisper installation without external dependencies.
- **SwiftUI Native Settings View**: The settings screen conforms to `PluginSettingsProvider` and renders native macOS controls with live audio validation ping (250ms silent pulse) to test key validity without consuming usage quotas.

---

### Building from Source

#### Prerequisites
- macOS Sonoma 14.0 or later (Apple Silicon `arm64`)
- TypeWhisper 1.6.0+ installed in `/Applications/TypeWhisper.app`
- Xcode Command Line Tools (`xcode-select --install`)

#### Build Steps

1. Clone this repository:
   ```bash
   git clone https://github.com/talkxo/typewhisper-sarvam-plugin.git
   cd typewhisper-sarvam-plugin
   ```

2. Run the packaging script:
   ```bash
   ./package_bundle.sh
   ```

This script will:
- Compile `SarvamPlugin.swift` in release mode using Swift Package Manager.
- Fix dynamic library linkage IDs via `install_name_tool`.
- Assemble the bundle structure (`Contents/MacOS/SarvamPlugin`, `Contents/Resources/manifest.json`, `Contents/Info.plist`).
- Ad-hoc code sign the bundle (`codesign --force --deep --sign -`).
- Automatically install the bundle into `~/Library/Application Support/TypeWhisper/Plugins/`.
- Generate a clean distribution archive at `~/Downloads/SarvamPlugin.zip`.

---

## ❓ Troubleshooting & FAQs

#### Q: It's typing in Devanagari Hindi instead of Hinglish English letters.
- Open **TypeWhisper > Settings > Integrations > Installed > Sarvam AI (Saaras)**.
- Make sure **Output Format / Style** is set to **Hinglish / Roman Script (Texting Style)** (`mode: "translit"`).
- Make sure **Spoken Language** is set to **Hindi (hi-IN)** (not `en-IN`, because setting `en-IN` instructs Sarvam to treat the speech as English).

#### Q: The plugin does not appear in TypeWhisper under Integrations.
1. Make sure you clicked the **Installed** tab at the top of the Integrations view (the default tab is **Discover** which only lists remote store items).
2. Check that the bundle exists at:
   ```bash
   ls ~/Library/Application\ Support/TypeWhisper/Plugins/SarvamPlugin.bundle
   ```
3. Restart TypeWhisper completely (`killall TypeWhisper && open -a TypeWhisper`).

#### Q: Where do I get a Sarvam API Key?
Sign up at [dashboard.sarvam.ai](https://dashboard.sarvam.ai). Sarvam offers trial credits upon registration for developer testing.

---

## 🤝 About TalkXO

Crafted with ❤️ by the team at **TalkXO** in India 🇮🇳.

Originally developed as an internal tool to solve our own day-to-day Hinglish dictation and messaging needs on macOS, and shared openly with the community as an enthusiastic enabler for Indic voice AI.

- 🌐 **Website**: [hello.talkxo.com](https://hello.talkxo.com)
- 💼 **GitHub**: [@talkxo](https://github.com/talkxo)

---

## ⚖️ Trademarks & Legal Disclaimer

- **Sarvam AI** and the **Saaras** speech model family (`saaras:v4`, `saaras:v3`, `saaras:v2.5`) are proprietary trademarks and intellectual property of **Sarvam AI Technologies Pvt. Ltd.**
- This project is an independent, community-driven integration enabler created by TalkXO. It is **not** an official product of Sarvam AI, nor is it affiliated with, endorsed by, sponsored by, or maintained by Sarvam AI.
- We make no claim or ownership over the Sarvam AI brand, trademarks, APIs, or underlying machine learning models.
- All speech-to-text processing occurs directly between your local Mac and Sarvam AI's official public REST API (`https://api.sarvam.ai/speech-to-text`) using your own developer API credentials, subject to Sarvam AI's terms of service and usage policies.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
