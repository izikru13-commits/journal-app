# Rega (רגע) – architecture plan

A single-user iOS 17+ app that reduces screen time with four mechanisms:
a friction **gate**, hard **scheduled locks** that only a physical key can end early,
honest **stats**, and **replacement activities**. Everything stays on the device.

## Targets

| Target | Type | Bundle id | Purpose |
|---|---|---|---|
| `Rega` | app | `com.neriya.rega` | SwiftUI app: onboarding, intervention flow, locks, key, stats, settings |
| `RegaShieldConfiguration` | app-extension (`com.apple.ManagedSettingsUI.shield-configuration-service`) | `.ShieldConfiguration` | Custom Hebrew shield UI; best-effort attempt counter; records bundle ids |
| `RegaShieldAction` | app-extension (`com.apple.ManagedSettings.shield-action-service`) | `.ShieldAction` | Shield buttons: "ויתרתי" → dismissal; "בכל זאת לפתוח" → pending request + local notification |
| `RegaMonitor` | app-extension (`com.apple.deviceactivity.monitor-extension`) | `.Monitor` | Lock schedules, re-shield timers, daily budget thresholds. Kept tiny (6 MB limit) |
| `RegaReport` | app-extension (`com.apple.deviceactivityui.report-extension`) | `.Report` | Screen Time dashboard (today total, pickups, top apps, 7-day chart) |
| `RegaWidget` | app-extension (`com.apple.widgetkit-extension`) | `.Widget` | Home + lock screen widgets with today's counters |
| `RegaTests` | unit tests (no host) | | Pure logic only (`Shared/Logic`) |
| `RegaUITests` | UI tests | | Screenshot tour of every screen in demo mode (CI) |

Every target that touches Screen Time has `com.apple.developer.family-controls`;
all targets share App Group `group.com.neriya.rega`. The app also has the NFC
tag-reading entitlement (optional NFC key).

## Source layout

```
rega/
  project.yml                  XcodeGen spec (reproducible multi-target project)
  Config/Rega.xcconfig         shared settings; includes optional Local.xcconfig (Team ID, git-ignored)
  Shared/Logic/                Foundation-only, unit-tested, compiled into every target
  Shared/Platform/             FamilyControls / ManagedSettings / DeviceActivity glue, compiled into every target
  Shared/Resources/            Localizable.xcstrings (Hebrew is the development language)
  App/                         main app
  Extensions/<Name>/           one folder per extension
  Tests/, UITests/
  scripts/                     setup.sh (Team ID + xcodegen), install-device.sh
```

## Data model (all Codable, App Group `UserDefaults`)

No SwiftData/CoreData anywhere: the monitor extension must stay far below 6 MB, and
small JSON values in `UserDefaults(suiteName:)` are the one storage every process can read.

| Key | Type | Writers | Notes |
|---|---|---|---|
| `selection.distractions` | `FamilyActivitySelection` (JSON) | app | the "distractions" group |
| `selection.lock.<uuid>` | `FamilyActivitySelection` | app | per-lock custom selection |
| `settings` | `RegaSettings` | app | delays, goal, budget, NFC, summaries, … |
| `locks` | `[LockRule]` | app | sleep / morning / custom repeating locks |
| `manualSession` | `ManualSession?` | app, monitor (cleanup) | "lock now" |
| `lockOverrides` | `[LockOverride]` | app | lock ended early (key / emergency) until occurrence end |
| `unlocks` | `[GateUnlock]` | app, all reconcilers | token + `allowedUntil` |
| `pendingRequest` | `PendingRequest?` | ShieldAction, app | encoded token + timestamp |
| `events` | `[RegaEvent]` | app, ShieldAction, ShieldConfiguration | 60-day log: attempt, dismissed, approved(+intention, minutes), lock events |
| `counters` | `[dayKey: DayCounters]` | same as events | compact per-day totals for extensions and widgets |
| `lastAttempts` | `[targetKey: Date]` | shield extensions | attempt de-duplication |
| `bundleIDs` | `[targetKey: String]` | ShieldConfiguration | for "open now" URL schemes |
| `budget` | `BudgetState` | app, monitor | monitoring start time, exceeded/warned/dismissed day |
| `emergencyUses` | `[Date]` | app | weekly emergency-exit counter |
| `key.secret`, `key.nfcTag` | `String` | app | physical key |
| `replacements` | `[ReplacementActivity]` | app | editable list |
| `installDate` | `Date` | app | streak lower bound |

A *target key* is a stable FNV-1a hash of the token's JSON encoding, prefixed with its
kind (`a`/`c`/`w`), so it fits in activity names and dictionary keys.

## Managed settings stores

* `ManagedSettingsStore(named: "gate")` – distractions minus active unlocks.
* `ManagedSettingsStore(named: "locks")` – union of active locks, manual session and budget;
  `application.denyAppRemoval` while a strict lock is active (setting, on by default).

iOS combines stores, so a gate unlock never weakens a lock.

## Single source of truth: `ShieldEngine.reconcile(now:)`

Every process (app on foreground / timer / background refresh, ShieldAction, monitor) calls
the same idempotent function. It prunes expired unlocks and manual sessions, evaluates
which locks are active **from the clock** (pure `ProtectionEvaluator`), and rewrites both
stores. Callbacks only *nudge* reconciliation, so a duplicated or early callback can never
create a state the clock does not justify. This is also the safety net that re-applies
expired unlocks whenever anything runs.

Monitor callbacks pass hints: a lock's `intervalDidStart` evaluates that lock 2 minutes in
the future (the callback can arrive a few hundred ms early), `intervalDidEnd` forces it off,
a relock `intervalDidStart` force-expires that unlock.

## Re-shield strategy (gate unlocks)

`DeviceActivitySchedule` must be ≥ 15 minutes. For an unlock of N minutes (1/5/10/15) we
start a non-repeating activity `rega.relock.<targetKey>` whose interval **starts** at
`allowedUntil` and ends 15 minutes later. `intervalDidStart` → reconcile (shield returns),
`intervalDidEnd` → stop monitoring that activity. Plus: the app re-checks every 20 s while
in the foreground, ShieldAction reconciles on every button press, and a `BGAppRefreshTask`
reconciles opportunistically.

## Locks

* One **daily repeating** activity per enabled lock (`rega.lock.<uuid>`), start → end
  (crosses midnight when needed; min 15 min, max 23 h 45 m). Days of week are checked in
  reconcile, which keeps us far below the ~20 activity limit.
* Manual session: activity `rega.manual` from now to end (durations ≥ 15 min).
* Strict lock shield: only a close button. Ending early needs the QR key (VisionKit
  `DataScannerViewController`, AVFoundation fallback), the paired NFC tag (optional), or an
  emergency exit (3 per Sunday-based week, exact Hebrew sentence).
* While strict: every protection-weakening setting is disabled (`ProtectionGuard`).

## Daily budget (best effort)

Activity `rega.budget` 00:00–23:59 daily with events at 80 % and 100 % of the budget on the
distractions group. `monitoringStartedAt` is stored at every (re)start and at each interval
start; threshold events within 60 s of it are ignored. The budget lock is never strict and
can always be ended from the app, so a spurious event can't trap the user.

## Shield flow

1. ShieldConfiguration renders "רגע." with today's attempt count and a rotating line,
   records an attempt (10 s de-dup per target) and the app's bundle id (best effort –
   writes from this extension are verified on device; ShieldAction is the reliable writer).
2. "ויתרתי" (dominant primary button) → ShieldAction logs attempt (if not logged in the
   last 2 min) + dismissed → `.close`.
3. "בכל זאת לפתוח" → ShieldAction saves `PendingRequest`, posts a local notification,
   `.close`. Tapping it opens the intervention: breathing countdown
   (8 s + 4 s per earlier approved open today, max 60) → intention chips → replacement
   activity for boredom/habit → duration → unlock + relock schedule → "open now" (URL scheme
   by bundle id) or "switch back to the app".

## Stats

* Screen Time (inside `RegaReport`, data cannot leave the extension): today total, pickups,
  top apps, 7-day chart.
* Rega's own (Swift Charts, in app): attempts/day, dismiss rate (hero metric),
  approved minutes, most common intention, streak of days with approved opens ≤ goal.
  Dismiss rate = attempts that did not end in an approved open ÷ attempts.

## Notifications

Gate continue, lock-end request (soft locks), budget warnings, evening summary (daily) and
weekly summary (Sunday 20:00). Summaries are re-scheduled with fresh numbers every time an
event is logged by the app or ShieldAction (local notifications can't compute content at
fire time).

## Localization / design

Hebrew development language, String Catalog in `Shared/Resources`, root views force
`layoutDirection = .rightToLeft` and `he_IL` locale. Dark-first palette, SF Symbols,
rounded type, 56 pt primary buttons.
