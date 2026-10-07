# Rega – progress

Verification environment: this code was written in a Linux cloud session without a Mac.
Every push is built by GitHub Actions on a macOS runner (`.github/workflows/rega-build.yml`):
unsigned device build, unit tests on the simulator, and a screenshot tour of every screen
(demo mode) published to the `rega-screenshots` branch. Real Screen Time behaviour can only
be verified on the iPhone (see the device checklist in `README.md`).

## Phases

| Phase | Scope | Status |
|---|---|---|
| 1 | XcodeGen project, 6 targets + tests, entitlements, App Group, CI | done |
| 2 | Authorization, picker, gate store, custom shield, ShieldAction → notification → intervention (breathing, intention, replacement, duration, relock schedule, open-now) | done |
| 3 | Scheduled locks (sleep, morning, custom, days of week), manual lock, strict shield, QR key (VisionKit + AVFoundation), NFC key, emergency exits, denyAppRemoval, protection guard | done |
| 4 | Stats (Swift Charts + DeviceActivityReport extension), widgets (home + lock screen), evening/weekly summaries | done |
| 5 | Onboarding (5 screens + tips), settings, daily budget, polish | done |

## Deviations and platform limits (honest list)

* **Built and tested in CI, not on your Mac.** The cloud session has no Xcode/Homebrew/iPhone.
  `scripts/setup.sh` runs the requested toolchain checks on your Mac.
* **Shield → app.** No public API lets a shield open an app. ShieldAction posts a local
  notification; tapping it opens the intervention (as specified).
* **Attempt counting.** The ShieldConfiguration extension counts shield displays (10 s
  de-dup) but Apple doesn't document whether it may write to the App Group. ShieldAction
  (documented to work) re-counts an attempt if none was recorded for that target in the last
  2 minutes. If on-device testing shows the configuration writes are dropped, attempts that end
  with a swipe-away (no button) won't be counted; everything else still is.
* **"Open now".** Needs the bundle id, which only the ShieldConfiguration extension can see
  (`Application.bundleIdentifier`). If that write is dropped, the screen falls back to
  "switch back to the app".
* **Category shields.** When an app is blocked only via a chosen category and iOS reports the
  category token to ShieldAction, the opening applies to the whole category for those minutes.
* **denyAppRemoval under `.individual`.** Implemented (setting, on by default) but whether iOS
  honours it under individual authorization must be confirmed on the device – it's on the
  checklist. If it turns out not to work, turn the setting off; nothing else depends on it.
* **Summaries.** Local notifications can't compute content at delivery time, so the evening and
  weekly summaries are re-scheduled with current numbers whenever the app or ShieldAction logs
  an event. If neither runs late in the day, the evening text is a few hours stale.
* **Manual lock durations start at 15 min** (DeviceActivity minimum), so no extra timer is needed.
* **Budget** is best effort and never strict (spurious-event guard of 60 s, can always be ended
  in the app), as specified.
* **NFC** reads the tag's hardware UID (NTAG/MIFARE/ISO 15693), not NDEF content, so any blank
  sticker works and it can't be cloned by copying text.
