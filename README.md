# Horizon

An Apple Watch app that rings at **sunrise** and **sunset**, every day, at the same times as Apple's Weather app. No iPhone, no network, no account.

> **Status:** specification. No code yet.

## In short

- **One gesture.** The main screen is the sun's arc; tap a bell at either end to turn that alarm on or off.
- **Every day, on its own.** Alarms re-arm themselves daily.
- **Two alarm levels.** Automatic: a time-sensitive notification plus a follow-up, scheduled weeks ahead. Persistent: once the app has been opened, the next alarm keeps vibrating until stopped.
- **Live countdown** to the next sunrise or sunset, in the app and on the watch face.
- **Complications** for every watch face slot (corner gauge, curved text, circular, rectangular, inline), a Smart Stack card and a Control Center toggle. Each one opens the app.
- **10 languages** at launch (12 locales), right-to-left included.

## Documents

| | |
|---|---|
| [Specification](docs/SPEC.md) | Behaviour of every screen, alarms, sun calculation, widgets, localization, privacy, architecture, tests, distribution |
| [UI strings](docs/strings.csv) | Every string in en, fr, es, es-419, pt-PT, pt-BR, it, nl, de, ja, zh-Hans, ar (first translation, to be reviewed by native speakers) |
| [Sun time fixtures](docs/fixtures/sun-times.csv) | Reference sunrise and sunset times for unit tests, including polar and daylight-saving cases |
| [Mockup](docs/mockup/) | One image per design section: main screen, countdown, navigation and settings, alarms, onboarding, complications, languages |

The images in `docs/mockup/` are exported from the design source, a private Figma file kept by TRENDev. Re-export them whenever the design changes.

![Horizon overview](docs/mockup/0-overview.png)

## Requirements

- Xcode 26 or later (Xcode 26 runs on Intel Macs)
- watchOS 26 deployment target, Swift and SwiftUI
- An Apple Watch for alarms, haptics and GPS (the simulator is enough for the UI)
- From April 2027, App Store uploads need Xcode 27; builds will go through Xcode Cloud

## Planned layout

```
Horizon.xcodeproj
HorizonApp/            watchOS app (SwiftUI)
HorizonWidgets/        complications, Smart Stack, control
Packages/HorizonCore/  sun calculation, alarm planning, notifications, settings
docs/                  specification, strings, fixtures
```

## License

Not decided yet. All rights reserved until then.
