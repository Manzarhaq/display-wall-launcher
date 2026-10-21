# Display Wall Launcher

A small native desktop app for showing one continuous website across one or two adjacent displays, without browser tabs, address bars or window borders. Mac uses AppKit/WKWebView; Windows uses WinForms/WebView2.

The app starts with a **blank URL**. Enter your own HTTP/HTTPS address; it is saved locally for next time. No website, server, credentials or offline content is included.

## Download and run

Download the ZIP for your platform from [Releases](https://github.com/Manzarhaq/display-wall-launcher/releases/latest).

| Download | Platform |
| --- | --- |
| `Display-Wall-Launcher-macOS-universal.zip` | Apple Silicon and Intel Macs, macOS 12+ |
| `Display-Wall-Launcher-Windows-x64.zip` | Windows 10/11 x64; .NET runtime included |

### Mac

Extract the ZIP, then open **Display Wall Launcher.app**. The app is ad hoc signed, not Developer ID signed or notarized. macOS may block the first launch. If you trust this download, attempt to open it, then go to **System Settings → Privacy & Security → Open Anyway**, confirm the app name and choose Open. See [Apple's instructions](https://support.apple.com/102445). On older macOS releases the settings application is called System Preferences. A managed Mac may require IT approval. Do not disable Gatekeeper globally or remove quarantine attributes.

For a two-display span, turn **Displays have separate Spaces OFF** under System Settings → Desktop & Dock → Mission Control, then **log out and back in**. Save other work first. The app reads the preference but never changes it or logs you out. If the setting is incompatible or cannot be read, use single-display preview until it is resolved. Native macOS fullscreen is deliberately not used.

### Windows

Extract **the entire ZIP into a folder** and run **DisplayWallLauncher.exe**. Keep all its companion files together. No .NET SDK or runtime installation is required. It uses the Microsoft Edge **WebView2 Evergreen Runtime**, often already installed. If missing, setup shows an installation link to [Microsoft's official runtime download](https://developer.microsoft.com/en-us/microsoft-edge/webview2/#download-section). Install the Evergreen Runtime and reopen the launcher. See [Microsoft's distribution guidance](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution).

The Windows executable is unsigned; Windows may show an unknown-publisher or SmartScreen warning. Only run a download you trust. Managed-device policy may require IT approval. There is no need to disable Defender or SmartScreen globally.

## Use

1. Enter the website address. Use **Preview on this screen** for a single-display trial.
2. Connect the two target displays using **extended desktop**, not mirroring. The adapter must expose two independent displays; duplicate-output hardware cannot produce a continuous canvas.
3. In the OS display arrangement, place the two target displays side by side with touching edges, aligned tops and equal heights. Mac uses scaled points; Windows uses pixel bounds. Do not put a third display between the targets.
4. Select one or two displays and click **Present**. One ordinary borderless window covers their combined bounds. On Mac, the menu bar and Dock hide while presenting and restore on exit. Windows uses a borderless topmost window over the target bounds.

| Action | Mac | Windows |
| --- | --- | --- |
| Return to setup | Escape or Cmd+. | Escape or Ctrl+. |
| Reload page | Cmd+R | Ctrl+R |
| Quit | Cmd+Q | Ctrl+Q or Alt+F4 |

A failed initial load returns to setup with a retry message. Choose Preview or Present again. Disconnecting or rearranging displays returns to setup so targets can be selected again. Once loaded, the website owns its own live-data/reconnection behavior. Network access is required. Certificate validation is not bypassed. Pop-up windows are not opened.

The app saves its URL/display choices locally. Websites may also store cookies in the platform webview profile. Use trusted sites; this is a presentation wrapper, not a lockdown kiosk or a browser replacement. It does not change global display or sleep settings. Keep the computer powered and choose suitable sleep settings before a long presentation.

## Physical check

Before use, verify the canvas crosses both physical displays continuously, all edges are visible, no OS chrome covers the picture, Escape returns to setup, and unplugging a display recovers safely. Display arrangement, adapters, DPI scaling and OS composition can affect the result. Window dimensions and CI success cannot prove physical spanning. A very wide website may letterbox on a single laptop display; the wrapper does not redesign or crop it.

## Build and checks

Mac requires Xcode or Command Line Tools with the Swift compiler and macOS SDK:

```sh
./macOS/test.sh
./macOS/build.sh
```

The build produces an ad hoc signed universal `.app` and ZIP in `dist/`. Interactive wrapper checks (each briefly opens a window and quits):

```sh
'dist/Display Wall Launcher.app/Contents/MacOS/DisplayWallLauncher' --smoke-blank
'dist/Display Wall Launcher.app/Contents/MacOS/DisplayWallLauncher' --smoke-test
'dist/Display Wall Launcher.app/Contents/MacOS/DisplayWallLauncher' --smoke-failure
```

`--smoke-blank` checks first-launch state; it expects no URL has been saved yet in the independent `io.github.displaywalllauncher` preferences domain. Tests do not save fixture addresses. The fixture is labelled and contains no remote content.

Windows requires .NET 10 SDK to build, not to run the download:

```powershell
./windows/build.ps1
$p = Start-Process dist/windows-x64/DisplayWallLauncher.exe -ArgumentList '--self-test', 'checks.txt' -Wait -PassThru
Get-Content checks.txt
if ($p.ExitCode -ne 0) { throw 'Checks failed' }
```

`--self-test` exercises geometry, URL validation and blank defaults. `--smoke-test report.txt` exercises the actual WebView2 fixture, back-to-setup and failed-load recovery on a Windows desktop with WebView2 installed. Build workflows run on GitHub-hosted Windows. Automated UI checks are not a manual Windows presentation test. The Mac universal binary is built for both architectures; an Intel hardware run and two physical external displays remain separate checks.

No automatic updater or background service is installed.
