# SnapShelf

**Label the shot. Shelf it. Yeet it from Photos.**

A Flutter app to tame screenshot hell: import/sort/label screenshots, browse by shelf (tag), and delete from the app **and** the device photo library when permissions allow.

## Why this exists

Detour after MyLoLCoach: that project hit a hard ceiling (live League data can’t support real coaching). SnapShelf’s promise is grounded — **capture → label → find → delete** — with a clear success test: *smaller Camera Roll, or find a shot in under 10 seconds.*

## Product rules (learned the hard way)

- Don’t invent causes the OS data can’t support.
- iOS won’t give a perfect “every screenshot → forced modal” hook; MVP is **share/import + library access**, not fantasy intercept.
- Android is more flexible for MediaStore delete; iOS needs proper Photos permissions and user-visible delete.

## MVP (2–3 weeks)

1. Import / share screenshot into the app  
2. **Mandatory** short label + shelf tags (`bug`, `work`, `receipt`, `meme`, `keep`)  
3. Grid by shelf + search on label  
4. Delete in app → delete from Photos when allowed; otherwise remove from app index + honest fallback  
5. Optional later: keyword → shelf rules (no AI required)

## Platforms

- **Android** + **iOS** (phone-first)  
- **Web** + **Windows** for UI iteration without a device  

## Stack

- Flutter 3.x / Dart  
- Local-first (no backend in MVP)  
- Persistence: `sqflite` (+ FFI on desktop), `shared_preferences` on web  
- Import: `photo_manager` (mobile, keeps asset id for delete) + `image_picker` (desktop/web / fallback)  
- Delete: `PhotoManager.editor.deleteWithIds` when linked + permitted; otherwise app-record-only with honest snackbar  

## Honest platform notes

| Surface | Import | Auto Screenshots album | Delete from Photos |
|---------|--------|------------------------|--------------------|
| Android | Library grid + sync | On open/resume + while app open | Yes, when permission granted |
| iOS | Library grid + sync | On open/resume (no button hook) | Yes with Read & Write |
| Chrome / Windows | File pick only | No | App-only |

SnapShelf **cannot** intercept the OS screenshot gesture/hotkey. Closest honest path: index the Screenshots album into **Unlabeled**, label whenever you have time.

## Repo layout

- `lib/` — app code  
- `HANDOFF.md` — full context for a **new Cursor chat**  
- `docs/TESTING.md` — UI testing without deploying to iOS hardware  

## Quick start (this machine)

Flutter SDK was installed at `C:\Tools\flutter`. Add to PATH permanently:

```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Tools\flutter\bin", "User")
```

Then:

```powershell
cd C:\Tools\SnapShelf
flutter pub get
flutter run -d windows
# or
flutter run -d chrome
```
