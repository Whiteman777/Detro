# Detro

A clean Flutter trip planner for the Cairo Metro. Pick a travel mode, type your start and stop stations (or let the app detect the nearest one from your location), and get the full route with transfer count, direction, estimated time, and ticket price. Fully bilingual English/Arabic, offline, and themed with Material You.

## Download

### 📱 Try the App

**[Download Detro v1.0.0 (APK)](https://drive.google.com/file/d/1NOebPXV_bDIZ6n75HSXEBsxABeoWIBng/view?usp=sharing)**

**Requirements:**
- Android 7.0 (Nougat) or higher
- ~16 MB download (arm64 APK)
- Location permission  only needed for the "nearest station" button, the planner works without it

**Installation:**
1. Download the APK from the link above
2. On your Android device, go to **Settings → Security**
3. Enable **"Install from unknown sources"** (or "Allow installs from this source" on newer Android)
4. Open the downloaded APK file and tap **Install**
5. Launch the app, type or detect your stations, and plan the trip

## Overview

Detro plans trips across the Cairo Metro network as it exists today: **Line 1** (New El-Marg ↔ Helwan), **Line 2** (Shubra El-Kheima ↔ El-Mounib), **Line 3** (Adly Mansour ↔ Rod El-Farag Corridor), and the **Line 3 Cairo University branch** (Kit Kat ↔ Cairo University) 90 station entries covering 84 unique stations, with real coordinates and measured inter-station travel times.

Two travel modes change what "best" means: **Comfortable** minimises transfers, while **Fastest** weighs actual travel minutes, transfer dwell time, and interchange walking. A trip summary reports the number of stations, the number of transfers, the estimated duration, and the Cairo Metro ticket price and validity window.

Everything runs on-device: no account, no backend, and no analytics. The only system service the app touches is location, and only when you tap the detect button.

The app demonstrates: single-source graph routing with a custom cost function, layered-graph modelling of interchanges, fuzzy text search, fused location provider handling, bilingual string handling without a codegen step, and dynamic Material You theming.

## Screenshots

*Coming soon*

## Features

- **Four lines**  Line 1, Line 2, Line 3, plus the Line 3 Cairo University branch (90 station entries, 84 unique stations)
- **Nearest station detection**  one tap picks the closest station to you and fills the start field
- **Comfortable / Fastest modes**  change the routing cost function, not just a label
- **Transfer-aware routing**  interchanges are modelled as explicit edges with dwell and walking time
- **Trip summary**  stations, transfers, estimated time, and ticket price
- **Direction guidance**  the terminus to head toward on the first leg of the trip
- **Ticket pricing**  10 / 12 / 15 / 20 EGP tiers with a 2-hour validity window
- **Fuzzy search**  case-insensitive, ignores everything that is not a letter, and tolerates typos within a Levenshtein distance of 3 (`el-marg`, `el_marg`, `El Marg` all match)
- **English / Arabic**  instant in-app toggle, including a right-to-left layout
- **Material You**  dynamic colour from the device wallpaper, with a teal fallback
- **Offline**  the entire network, timing, and pricing data ships with the app

## Architecture

### Layered Graph Routing

The network is modelled as a graph of **`station|line` nodes** rather than plain stations, so a station served by two lines becomes two nodes joined by a transfer edge. This is what makes "avoid transfers" and "minimise time" expressible as a cost function instead of a heuristic:

```
Line 1: New El-Marg ──── El-Marg ──── … ──── Helwan
                                 ╲
                                  ╳  transfer edge (dwell + walking time)
                                 ╱
Line 2: Shubra El-Kheima ──── … ──── El-Mounib
```

Routing is a single-source **Dijkstra** over that graph, terminating as soon as any node for the destination station is settled:

```dart
final hopCost = switch (gateMode) {
  GateMode.comfortable => 1.0,
  GateMode.fastest     => travelMinutesFrom(station),
};

final transferCost = switch (gateMode) {
  GateMode.comfortable => _transferPenaltyStops,               // 10000
  GateMode.fastest     => transferDwellMinutes + walkMinutesAt(station),
};
```

**Key details:**
- **Comfortable** charges 1 per hop and 10000 per transfer, so it effectively finds the fewest-transfer path
- **Fastest** charges real per-station travel minutes and true transfer cost
- Transfers do **not** increment the hop count, so "stations" on the summary means stops, not boardings
- Neighbours are only expanded when the order difference is exactly 1, which prevents line-endpoint wrap-around
- The settled-node set guarantees the first destination node popped is the cheapest one

### Data Model

Lines and stations are plain immutable data  a `MetroLine` is a name, an ordered station list, a headway, and a default segment time:

```dart
class Station {
  final String name;
  final int order;          // position along the line
  final bool isTransitional; // temporarily closed / out of service
}

class MetroLine {
  final String name;
  final List<Station> stations;
  final double headwayMinutes;
  final double segmentMinutes;  // default 2.0
}
```

**`isTransitional`** flags stations that are modelled but not in normal service. It is populated in the data files but not yet enforced by the router  see [Marking a Station as Closed](#marking-a-station-as-closed).

### Timing & Pricing

Timing is data, not arithmetic. `travel_times.dart` holds per-station travel minutes and per-interchange walking minutes, with sensible defaults everywhere else:

**Note:** `stationTravelMinutes` and `interchangeWalkMinutes` are looked up with the *normalized* station name (lowercase, spaces stripped), so their keys must be in that form too. Several entries in the current data file still carry spaces (e.g. `'helwan university'`), which makes them unreachable and silently falls back to the 2.0 / 5.0 defaults. Normalize the keys when editing these maps.

```dart
const double defaultStationTravelMinutes = 2.0;
const double defaultInterchangeWalkMinutes = 5.0;
const double transferDwellMinutes = 6.0;
```

A trip's duration is recomputed from the final path  travel minutes for same-line edges, `transferDwellMinutes + walkMinutesAt(...)` for transfer edges.

Ticket price is derived from hops only, matching the real fare tiers:

```dart
enum TicketType {
  basic(10),
  standard(12),
  extended(15),
  longDistance(20);

  static const int duration = 2; // hours of validity

  static TicketType forHops(int hops) => switch (hops) {
        <= 9  => basic,
        <= 16 => standard,
        <= 23 => extended,
        _     => longDistance,
      };
}
```

### Nearest-Station Detection

`NearbyStationLocator` asks `geolocator` for a position and picks the closest station by **haversine** distance using a bundled coordinate table for all 84 stations.

The policy is deliberately permissive: it accepts whatever fix the device hands over, with **no distance, timestamp-age, or accuracy rejection**, because a 5 km-away answer beats telling a user nothing. Failures are limited to the cases where no position is obtainable at all  location services off, permission denied or permanently denied, or a timeout:

- Tries the fused provider with a time bound, then falls back to `forceLocationManager: true` for devices that hold a stale fused fix
- Uses a `lastKnownLocation` fallback if a live fix times out
- Reports the picked station and its distance so the result is never silently wrong

Detection only fills the start field. The user can always overwrite it, and the planner never asks for location on launch.

### Bilingual UI

There are no ARB files and no codegen. A single helper keeps every string pair adjacent so translators can work on one file:

```dart
enum AppLang { english, arabic }

String _tr(AppLang lang, String en, String ar) =>
    lang == AppLang.english ? en : ar;
```

`MaterialApp` receives `locale: Locale('ar')`, so the body picks up RTL from the ambient `Directionality` with no per-widget branching. The **app bar is the one exception**  it is wrapped in an explicit `TextDirection.ltr` so the left-aligned `Detro` title does not jump to the right edge in Arabic:

```dart
child: Directionality(
  textDirection: TextDirection.ltr,
  child: AppBar(title: const Text('Detro'), centerTitle: false),
),
```

Station display names are also localised: `arabic_stations.dart` maps each station key to its Arabic name for the picker and the results route.

### Fuzzy Search

Station lookup normalises input down to letters only, then ranks candidates by Levenshtein distance, so partial and misspelled names still resolve:

```dart
String normalize(String s);   // keep only a-z and Arabic letters
int levenshtein(String a, String b);
List<String> fuzzyRank(String query, Iterable<String> candidates, {int maxDistance = 3});
```

## Getting Started

### Prerequisites

- Flutter SDK (3.47+)
- Dart SDK (3.13+)
- Android Studio / VS Code with Flutter extensions
- An Android 7.0+ device or emulator with GPS for the nearest-station feature

### Clone & Run

```bash
# Clone the repository
git clone https://github.com/Whiteman777/Metro-App.git
cd Metro-App

# Install dependencies
cd app
flutter pub get

# Run the app
flutter run
```

### Run Tests

```bash
flutter test
```

14 tests: 7 for the nearest-station failure modes, plus 6 widget/unit tests (planner renders, station picker, Arabic toggle, fuzzy typo and ranking, cross-line graph routing) and 1 for the detected-station field sync.

### Build APK

```bash
flutter build apk --release
```

Output: `app/build/app/outputs/flutter-apk/app-release.apk`

For smaller per-architecture APKs:

```bash
flutter build apk --release --split-per-abi
```

Output: `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` etc.

For the smallest APK, obfuscate and strip Dart symbols out of the binary:

```bash
flutter build apk --release --target-platform android-arm64 \
  --obfuscate --split-debug-info=build/symbols
```

Keep `build/symbols/`  `flutter symbolize` needs it to read stack traces from the obfuscated build.

### Measured APK Sizes

| Build | Size |
|---|---|
| `--target-platform android-arm64 --obfuscate` | 16.4 MB |
| `--split-per-abi` arm64-v8a | 17.2 MB |
| `--split-per-abi` armeabi-v7a | 14.8 MB |
| `--split-per-abi` x86_64 | 18.7 MB |

Most of the remaining weight is the engine: `libflutter.so` is ~11 MB and the Dart AOT blob `libapp.so` ~5 MB per ABI.

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.8   # iOS-style icons
  dynamic_color: ^1.7.0      # Material You palette from the device
  geolocator: ^14.1.1        # nearest-station detection

dev_dependencies:
  flutter_test:
    sdk: flutter
  geolocator_platform_interface: ^4.4.0  # fake position provider in tests
  plugin_platform_interface: ^2.1.8
  flutter_lints: ^6.0.0
```

## Project Structure

```
app/
├── lib/
│   ├── main.dart                  # UI, bilingual strings, planning screen
│   ├── theme.dart                 # Material You + teal fallback themes
│   ├── data/
│   │   ├── elmarg_line.dart       # Line 1 stations
│   │   ├── elmounib_line.dart     # Line 2 stations
│   │   ├── rod_elfarag_line.dart  # Line 3 stations
│   │   ├── cairo_university_branch.dart  # Line 3 Cairo University branch
│   │   ├── arabic_stations.dart   # display name → Arabic display name
│   │   ├── station_coordinates.dart      # lat/lng for all 84 stations
│   │   └── travel_times.dart            # inter-station + interchange minutes
│   ├── models/
│   │   ├── station.dart           # name, order, isTransitional
│   │   ├── metro_line.dart        # stations, headway, segment time
│   │   └── ticket.dart            # fare tiers by hops
│   ├── services/
│   │   ├── metro_graph.dart       # layered graph, Dijkstra, directions
│   │   └── nearby_station_locator.dart  # geolocator + haversine nearest
│   └── utils/
│       └── normalize.dart         # input normalisation + fuzzy ranking
├── test/
│   ├── widget_test.dart
│   ├── nearby_station_locator_test.dart
│   └── station_field_sync_test.dart
└── android/app/src/main/AndroidManifest.xml   # location permissions
```

## Extending the App

### Adding a Station

Append it to the relevant line with the correct `order`, and add it to the three lookup tables. Note the key style differs per file:

```dart
// lib/data/elmarg_line.dart — the order position along the line
const Station(
  name: 'Some New Station',
  order: 14,
  isTransitional: false,
),

// lib/data/station_coordinates.dart — key is the NORMALIZED name
'somenewstation': (30.050000, 31.260000),

// lib/data/travel_times.dart — key is also the NORMALIZED name
'somenewstation': 3.0,

// lib/data/arabic_stations.dart — key is the DISPLAY name
'Some New Station': 'محطة جديدة',
```

**Important:** a station served by more than one line must be listed in each line's data. The graph discovers the interchange from the duplicate entry — there is no separate interchange table.

### Adding a Line

Create a `MetroLine` in `lib/data/`, then register it in `MetroGraph`'s line list and add a label in `lineLabel()`:

```dart
MetroLine lineLabel(MetroLine line) => switch (line.name) {
      'elmarg' => 'Line 1',
      'elmounib' => 'Line 2',
      'rodelfarag' || 'cairoUniversity' => 'Line 3',
      _ => line.name,
    };
```

### Marking a Station as Closed

Set `isTransitional: true` in the line data. Be aware that the flag is currently **declarative only**  the router still routes through such stations, and the station picker still offers them. To enforce it, filter on the flag in the picker's candidate list and skip those nodes during graph expansion in `MetroGraph.shortestTrip`.

### Customizing the Theme

Change the fallback seed in `lib/theme.dart`; the Material You palette is applied automatically when the device exposes one:

```dart
const Color brandSeed = Color(0xFF00C6A5);
```

## Application Flow

```
[Planner Screen]
     ↓ (tap "Use my location" or type a station)
[Station picker / Autocomplete]        ← fuzzy match, RTL-aware
     ↓ (start + stop chosen, mode selected)
[MetroGraph.shortestTrip]              ← Dijkstra on station|line nodes
     ↓
[Trip summary]                         ← stations, transfers, time, price
     ↓ (first leg)
[Direction card]                       ← terminus to head toward
```

## License

This project is open source and available for educational purposes.
