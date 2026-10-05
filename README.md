# Horizon

An Apple Watch app that rings at **sunrise** and **sunset**, every day, at the same times as Apple's Weather app. No iPhone, no network, no account.

> **Status:** milestones M1 to M4 of the [specification](docs/SPEC.md) are built and run in the watch simulator. Not yet tried on a real watch; M5 (native review of the translations, store pages, TestFlight) is still to do.

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

- Xcode 26 or later (Xcode 26 runs on Intel Macs), with the watchOS 26 simulator runtime (`xcodebuild -downloadPlatform watchOS`)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to regenerate the project (`brew install xcodegen`)
- watchOS 26 deployment target, Swift 6 and SwiftUI
- An Apple Watch for alarms, haptics and GPS (the simulator is enough for the UI)
- From April 2027, App Store uploads need Xcode 27; builds will go through Xcode Cloud

## Build and test

```sh
# Core logic: sun calculation, planner, notification budget. Runs on the Mac, no simulator.
swift test --package-path Packages/HorizonCore

# App and widget extension
xcodegen generate
xcodebuild -project Horizon.xcodeproj -scheme Horizon \
    -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 3 (49mm)' build

# UI tests on the simulator; screenshots are exported to build/ui-tests
Tools/ui_tests.sh

# Just see the app: builds, opens the Simulator window and launches Horizon
Tools/run_sim.sh build/horizon.png
```

`xcrun simctl` boots a simulator without a window. The two scripts open the Simulator app for you; otherwise run `open -a Simulator`.

`Horizon.xcodeproj` is generated from `project.yml` and committed, so the repository opens in Xcode as is. Change `project.yml`, not the project.

To run on a watch, put your team in `Configuration/Local.xcconfig`, next to `Config.xcconfig` (it is not committed):

```
DEVELOPMENT_TEAM = ABCDE12345
```

The bundle identifiers are `fr.trendev.horizon` and `fr.trendev.horizon.widgets`, the App Group `group.fr.trendev.horizon`.

## Layout

```
project.yml            XcodeGen description of the project
Horizon.xcodeproj      generated from it
HorizonApp/            watchOS app (SwiftUI): screens, alarm session, notifications
HorizonWidgets/        complications, Smart Stack card, Control Center toggle
Shared/                palette, formatters and the toggle's intent, used by both targets
HorizonUITests/        UI tests for the simulator
Packages/HorizonCore/  sun calculation, alarm planning, notifications, city index, settings
Tools/                 generators and scripts (below)
docs/                  specification, strings, fixtures, mockup
```

## Tools

| Script | What it does |
|---|---|
| `Tools/generate_strings.py` | Builds `Localizable.xcstrings` and `InfoPlist.xcstrings` from `docs/strings.csv`. Edit the CSV, never the catalogs. |
| `Tools/build_cities.py` | Downloads GeoNames *cities15000* and writes the offline city list `cities15000.bin`. The only step that uses the network, and only on the Mac. |
| `Tools/generate_fixtures.py` | Recomputes `docs/fixtures/sun-times.csv` with astral at the spec's −0.833° horizon. |
| `Tools/make_icon.swift` | Draws the app icon. |
| `Tools/run_sim.sh` | Builds, opens the Simulator window, launches the app with launch arguments and saves a screenshot. |
| `Tools/ui_tests.sh` | Runs the UI tests and exports their screenshots. |
| `Tools/check_notifications.sh` | Prints how many notifications the app scheduled (expected: at most 61 of the 64 allowed). |

Debug builds accept launch arguments that reproduce a scene, for screenshots and tests. The mockup's scene, Paris on 29 September 2026 at 16:17:

```sh
Tools/run_sim.sh main.png -horizonSkipOnboarding YES -horizonReset YES \
    -horizonNow 2026-09-29T16:17:00+02:00 -horizonLocation 48.8566,2.3522 -horizonTimeZone Europe/Paris
```

They are listed in `HorizonApp/DebugOverrides.swift` and do nothing in release builds.

## License

Not decided yet. All rights reserved until then.
