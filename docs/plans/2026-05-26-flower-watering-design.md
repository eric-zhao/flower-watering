# Flower Watering — Design

**Date:** 2026-05-26
**Status:** Approved, ready to implement
**Target platforms:** Android (primary), Chrome (dev preview), iOS (future)

## Problem

Track several plants/trees at home, each with its own watering frequency. The
owner wants a quick visual indicator of which plants need water now and which
are still fine, without having to remember per-plant schedules.

## Goals

- Add a plant with a photo, name, and watering frequency (in days).
- Mark a plant as watered on a chosen date.
- Display remaining days and a color bar that shifts from green (just watered)
  through yellow to red (due / overdue).
- Notify the user when a plant becomes due.
- Delete plants.
- Work as an installable Android APK; preview in Chrome during development;
  reuse the same codebase for iOS later.

## Non-goals (v1)

- Cloud sync / multi-device.
- Plant categories, tags, search.
- Per-plant notification lead time (e.g. "remind 1 day early").
- Full watering history log — only the last watered date is stored.
- Account system.

## Stack

- **Framework:** Flutter (Dart). One codebase → Android APK + Chrome dev
  preview + future iOS build.
- **State:** simple repository pattern over a Hive box (`provider` only if a
  screen needs widely-shared reactive state — likely unnecessary at this scope).
- **Storage:** `hive` / `hive_flutter` for plants. Images stored as files in
  the app docs directory; their paths are saved in the plant record.
- **Plugins:**
  - `image_picker` — gallery / camera
  - `path_provider` — app docs directory
  - `flutter_local_notifications` — Android notifications
  - `intl` — date formatting
  - `uuid` — plant IDs

## Directory layout

```
flower-watering/
├── pubspec.yaml
├── lib/
│   ├── main.dart                       # entrypoint, Hive + notification init
│   ├── models/plant.dart               # Plant + Hive adapter
│   ├── services/
│   │   ├── plant_repository.dart       # CRUD on Hive box
│   │   ├── image_service.dart          # copy picked images into app docs dir
│   │   └── notification_service.dart   # schedule/cancel water-due notifs
│   ├── screens/
│   │   ├── home_screen.dart            # list of plants sorted by urgency
│   │   ├── add_plant_screen.dart       # form: photo + name + frequency
│   │   └── plant_detail_screen.dart    # detail, mark-watered, delete
│   └── widgets/
│       ├── plant_card.dart             # row: thumb + name + bar + days text
│       └── water_level_bar.dart        # green→yellow→red gradient bar
├── docs/plans/2026-05-26-flower-watering-design.md
└── README.md
```

## Data model

```dart
@HiveType(typeId: 0)
class Plant {
  @HiveField(0) String id;            // uuid v4
  @HiveField(1) String name;
  @HiveField(2) String imagePath;     // absolute path inside app docs dir
  @HiveField(3) int frequencyDays;    // 1..365
  @HiveField(4) DateTime lastWatered; // normalized to local midnight
}
```

### Derived values

```dart
int daysSinceWatered(DateTime now) =>
    now.difference(lastWatered).inDays;          // floor of whole days

int remainingDays(DateTime now) =>
    frequencyDays - daysSinceWatered(now);       // can be negative

double waterLevel(DateTime now) =>
    (remainingDays(now) / frequencyDays).clamp(0.0, 1.0);
```

### Color logic

```dart
Color barColor(double level) {
  // 1.0 → green, 0.5 → yellow, 0.0 → red
  if (level >= 0.5) {
    return Color.lerp(Colors.yellow, Colors.green, (level - 0.5) * 2)!;
  }
  return Color.lerp(Colors.red, Colors.yellow, level * 2)!;
}
```

Overdue (`remainingDays <= 0`) → solid red bar, label reads
`"Overdue by N days"`.

### Sort order

Home list is sorted ascending by `remainingDays`, so the most urgent (red) is
at the top.

### Time handling

All dates are normalized to **local midnight** on save. Watering today always
yields exactly `frequencyDays` remaining, regardless of clock time.

## Screens

### Home

AppBar with `+` button. List of `PlantCard` rows (thumb, name, color bar,
remaining-days text). Tapping a row opens the detail screen. Pull-to-refresh
re-renders, useful when the day rolled over while the app sat open. Empty
state: "No plants yet — tap + to add one."

### Add plant

Form fields:
1. Photo — tap placeholder → bottom sheet (Camera / Gallery / Cancel). Picked
   file is copied into app docs dir; new path stored.
2. Name — text, required, ≤ 40 chars.
3. Watering frequency (days) — number input, required, 1–365.

Save → new `Plant` with `id = uuid`, `lastWatered = today (midnight)` → write
to Hive → schedule notification → pop.

### Plant detail

- Large photo, name in AppBar, trash icon (with confirm dialog).
- Read-out: "Every N days", "Last watered: <date>", remaining-days line,
  color bar.
- **Mark as Watered** button — droplet icon writes `lastWatered = today`;
  calendar icon opens `showDatePicker` to backdate. Either way, recompute,
  reschedule notification, re-render.

## Notifications

`notification_service.dart` wraps `flutter_local_notifications`.

- On app start: init plugin, request `POST_NOTIFICATIONS` on Android 13+.
- On plant created / watered: cancel existing notification for that plant,
  schedule a new one for `lastWatered + frequencyDays` at 09:00 local with
  body `"Time to water {plant.name}"`.
- On plant deleted: cancel the notification.
- Notification ID = first 31 bits of `plant.id` hash (Android needs int).
- All scheduling calls guarded by `if (!kIsWeb)` — no-op in Chrome.

## Platform differences (Chrome vs Android)

| Behavior        | Chrome preview                     | Android APK                       |
| --------------- | ---------------------------------- | --------------------------------- |
| Photo picker    | OS file dialog                     | Camera or gallery picker          |
| Storage         | IndexedDB-backed Hive              | App sandbox + filesystem images   |
| Notifications   | Skipped (no-op)                    | OS notification at 09:00          |
| Back nav        | Browser back arrow                 | System back gesture               |

Color bar, calendar picker, list rendering, and day-math behave identically.

## Build & run

```bash
flutter pub get                       # one-time
flutter run -d chrome                 # dev preview with hot reload
flutter build apk --release           # produces app-release.apk for sideload
# (future) flutter build ios          # iOS, once on a Mac with Xcode
```

## Risks / open issues

- **Day boundary on overnight emulator:** if Chrome stays open across
  midnight, remaining-days won't update without pull-to-refresh. Acceptable
  for v1.
- **Backdating past the previous due date:** e.g. plant due every 10 days,
  user backdates to "watered 12 days ago" → starts overdue. Allowed; the math
  still works.
- **Image rotation on Android:** `image_picker` returns the original EXIF
  orientation; we'll display with `Image.file` which respects EXIF on Android
  but **not** in Chrome. Acceptable display quirk in dev preview.
- **Web data loss on browser-storage clear:** users clearing Chrome site data
  will lose plants. Dev-preview-only concern.
