# HANDOFF — open a new Cursor chat on this

**Do this:** Cursor → **New Agent / New Chat** → **Open folder** `C:\Tools\SnapShelf` → attach or `@HANDOFF.md` + `@README.md`.

This file is the full context dump so you don’t need the MyLoLCoach thread.

---

## Origin

User cooled off on **MyLoLCoach** (League coaching). Live tips + Electron overlay hit compromises: thin Live Client data, invented coaching (“likely gave up farm”), overlay fighting DirectX. Post-game honesty pass helped, but user considered it a small failure and wanted a detour.

Interests: gaming, gym, MTB, programming, DIY. Liked **Programming / builder toys**; chose the **screenshot vault** idea.

## Product name

Working title: **SnapShelf** (PC-friendly; not “screenshot hell”). Tagline: label → shelf → delete from Photos.

Alternatives if rename: ShotClerk, RollClerk, ShelfShot.

## Problem

iOS Camera Roll fills with screenshots; cleaning in Photos is painful. Want: sort, label, categorize, **delete without opening Photos**.

## Scope agreements

| Topic | Decision |
|-------|----------|
| Stack | Flutter (iOS + Android) |
| Similar to MyLoLCoach? | No Spring-first; phone app. Optional sync later |
| Success metric | After ~2 weeks: roll smaller OR find a shot &lt;10s |
| AI coach | Not the hero; optional keyword rules only |
| iOS screenshot intercept | Not MVP — share sheet / import / limited library access |
| Delete from library | Goal yes; implement with platform permissions; honest fallback if denied |

## MVP checklist

- [x] Local DB of shots (path/id, label, shelves, createdAt)
- [x] Import image (gallery / share target)
- [x] Label on ingest **or label later** (Unlabeled default)
- [x] Shelves / tags + search + **custom shelves**
- [x] Delete: app record + Photos asset when permitted
- [x] Empty / onboarding copy that sets expectations on iOS permissions
- [x] Screenshots album sync on open/resume (Android/iOS) → Unlabeled

Share-sheet entry (iOS “share to SnapShelf”) is still open — import picker covers gallery for now.

**Cannot do (OS):** hook the system screenshot button/hotkey; perfect background ingest on iOS while the app is killed. Sync runs when SnapShelf is opened/resumed (and while foreground via library change notify).

## Explicit non-goals (v1)

- Live overlay on games  
- Cloud sync / accounts  
- LLM auto-caption as required path  
- Perfect background “on every screenshot” on iOS  

## Suggested next slice

1. Android emulator pass: permission dialogs + MediaStore delete confirmation  
2. iOS Mac/device pass: Read & Write Photos + limited-library honesty  
3. Optional: iOS/Android share target so Screenshot → Share → SnapShelf skips the in-app picker  

## Related rejected / parked ideas

MTB log, gym tracker, DIY lab, error graveyard, webhook inbox — user preferred screenshot app for phone daily use.

## Tone for future work

Direct, honest about OS limits, no overclaiming. Prefer silence / facts over hedged fake coaching (lesson from MyLoLCoach).
