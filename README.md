# Flower Watering

A small Flutter app for tracking when each of your houseplants needs water.
Add a plant with a photo, name, and watering frequency; mark it watered; the
home screen shows a green-to-red color bar for each plant based on how many
days remain.

Cross-platform: develops in Chrome, ships as an installable Android APK, and
the same codebase can target iOS later.

## Status

Designed, not yet implemented. See
[`docs/plans/2026-05-26-flower-watering-design.md`](docs/plans/2026-05-26-flower-watering-design.md)
for the full design.

## Planned dev workflow

```bash
flutter pub get               # one-time install
flutter run -d chrome         # dev preview in browser with hot reload
flutter build apk --release   # produce installable APK for Android
```

## License

MIT.
