# Sarvam AI (Saaras) Plugin for TypeWhisper (Windows Edition) 🪟

This is the Windows (.NET / C#) edition of the Sarvam AI plugin for [TypeWhisper for Windows](https://github.com/TypeWhisper/typewhisper-win).

Crafted with ❤️ by the team at [**TalkXO**](https://hello.talkxo.com).

---

## Installation on Windows

### Quick Install (Pre-built)
1. Download `TypeWhisper.Plugin.Sarvam-windows.zip` from [Releases](https://github.com/talkxo/typewhisper-sarvam-plugin/releases).
2. Extract the folder to your TypeWhisper Windows plugin directory:
   ```cmd
   %LocalAppData%\TypeWhisper\Plugins\com.typewhisper.sarvam\
   ```
   The folder should contain:
   - `TypeWhisper.Plugin.Sarvam.dll`
   - `manifest.json`
3. Restart TypeWhisper for Windows.
4. Go to **Settings > Integrations > Sarvam AI (Saaras)**, enter your API key, and select **Hinglish / Roman Script**.

---

## Building from Source

### Prerequisites
- Windows 10/11
- [.NET 10 or .NET 8 SDK](https://dotnet.microsoft.com/download)

### Build Steps

#### Option A: Standalone Build
```cmd
cd windows\TypeWhisper.Plugin.Sarvam
dotnet build -c Release
```

#### Option B: Inside the `typewhisper-win` Repository Tree
Clone or copy `TypeWhisper.Plugin.Sarvam` into `plugins\` of `typewhisper-win`:
```cmd
git clone https://github.com/TypeWhisper/typewhisper-win.git
cd typewhisper-win
mkdir plugins\TypeWhisper.Plugin.Sarvam
xcopy /E /I path\to\TypeWhisper.Plugin.Sarvam plugins\TypeWhisper.Plugin.Sarvam
dotnet build plugins\TypeWhisper.Plugin.Sarvam\TypeWhisper.Plugin.Sarvam.csproj -c Release
```

---

## Trademarks & Disclaimer
Sarvam AI and Saaras are trademarks of Sarvam AI Technologies Pvt. Ltd. This plugin is an independent community integration developed by TalkXO.
