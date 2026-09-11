# UI testing without deploying to a physical iOS device

You’re on **Windows**. You **cannot** run the iOS Simulator here (needs macOS). You can still build and click through almost all UI.

## What to install

| Tool | Why |
|------|-----|
| **Flutter SDK** | Already at `C:\Tools\flutter` — add `C:\Tools\flutter\bin` to your User PATH |
| **Git** | Already used to clone Flutter |
| **Chrome** | Fastest UI loop: `flutter run -d chrome` |
| **Visual Studio 2022** (or Build Tools) with **Desktop development with C++** | Required for `flutter run -d windows` |
| **Android Studio** + Android SDK + an **AVD emulator** | Closest to phone UI/gestures without a device |
| **VS Code** or **Android Studio** + Flutter/Dart plugins | Hot reload, DevTools |

Optional later (real iPhone / TestFlight): a Mac, or CI (Codemagic / GitHub Actions macOS runners).

Check setup:

```powershell
$env:PATH = "C:\Tools\flutter\bin;$env:PATH"
flutter doctor
```

## Phone-shaped UI without an emulator

No Android SDK is installed on this machine yet (`flutter doctor` → Android toolchain missing). Until you install Android Studio + an AVD:

1. `flutter run -d chrome` — SnapShelf wraps the app in a **390×844 phone frame** on wide browser windows.
2. Or Chrome DevTools → Toggle device toolbar (Ctrl+Shift+M) for extra chrome.

Real emulator later:

```powershell
# Install Android Studio, then create a Pixel AVD, then:
flutter emulators
flutter emulators --launch <emulator_id>
flutter run -d android
```

List devices:

```powershell
flutter devices
```

## Widget tests (no device at all)

```powershell
flutter test
```

Use `flutter_test` + later `integration_test` for flows. Screenshots of UI: **Golden tests** or Flutter DevTools.

## What you still can’t verify on Windows alone

- Real **iOS Photos** permission sheets and delete-from-library behavior  
- Share-sheet entry from iOS Screenshot markup  

Plan: UI + Android first; borrow/borrow a Mac or use cloud macOS when wiring `photo_manager` delete on iOS.

## Hot reload

While `flutter run` is active: save a Dart file, or press `r` (hot reload) / `R` (hot restart) in the terminal.
