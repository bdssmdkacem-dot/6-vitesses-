# 6 VITESSES — DIGITAL GT

Android Flutter driving dashboard / HUD.

**Core principle:** evolve the app without breaking the features that already work. Existing GPS, IMU, HUD styles, navigation, mirror mode, history, permissions and CI are preserved while new features are added incrementally.

## Current product identity

**6 VITESSES — DIGITAL GT**

The app is a real driving instrument-cluster HUD:

- GPS vehicle speed with resilient reconnect/watchdog handling.
- Accelerometer/IMU motion and G-force measurement.
- Landscape immersive HUD with keep-awake behavior.
- Mirror mode for windshield/HUD reflection.
- Automatic gear estimation.
- Driving sessions, statistics and local history.
- Global OpenStreetMap place search.
- Destination confirmation and OSRM driving routes.
- Turn-by-turn navigation rendered directly inside the HUD.
- Navigation state machine with off-route detection and rerouting.
- Traffic-sign engine integrated with route context.
- Network-failure preservation of the active navigation session.
- Global map/routing architecture.
- Optional OBD-II architecture prepared for future ELM327 support.

## HUD styles

The original working styles remain available:

- **DIGITAL CLASSIC** — original digital dashboard.
- **CIRCULAR** — circular gauge.
- **LINEAR** — linear gauge.
- **DIGITAL GT** — new selectable GT identity.

Selecting DIGITAL GT does **not** replace the classic styles.

### Digital GT layouts

DIGITAL GT contains three selectable layouts using the same navigation and traffic-sign engine:

| Layout | Main purpose | Map | Navigation | Signs | Driving data |
|---|---|---:|---:|---:|---:|
| **NAV GT** | Navigation-focused cockpit | Yes | Full | Full rail | Speed, trip, ETA, road |
| **SPORT GT** | Performance cockpit | No | Compact | Critical only | G-force, gear, performance |
| **TOURING GT** | Long-drive cockpit | Mini map | Full | Full rail | G-force, trip, ETA, road |

The layout selection is persisted in settings.

## Navigation architecture

`GPS / OSRM → Navigation Engine → Traffic / Sign Engine → Navigation HUD Overlay → Mirror Layer`

The navigation system currently supports:

- Global place-name search.
- Destination confirmation before navigation.
- Route generation.
- Navigation session states: idle, navigating, off-route, rerouting, arrived.
- Route projection and maneuver progression.
- Distance to next maneuver.
- Road/maneuver guidance in the HUD.
- Speed-limit/sign context where OSM data is available.
- STOP / Give Way / traffic-light / roundabout sign handling.
- Heading confidence based on vehicle speed.
- Reroute cooldown.
- Network-failure preservation of the current navigation session.
- Map tile fallback.

## Sensors and vehicle data

### Currently working

- GPS speed.
- GPS heading/position.
- GPS permission flow and reconnect watchdog.
- Accelerometer-based motion/G-force.
- Responsive acceleration/braking model.
- Automatic gear estimation.
- Speed unit selection.
- Maximum speed and braking/acceleration metrics.
- Trip/session history.

### Prepared architecture

OBD-II is optional and does not block normal GPS operation.

The OBD layer separates:

- `ObdAdapter`
- `ObdTransport`
- `Elm327Session`

Prepared PID support includes:

- Engine load.
- Coolant temperature.
- RPM.
- Vehicle speed.
- Throttle position.

A real Android Bluetooth/ELM327 transport is still a future production task.

## App branding assets

Launcher source:

`assets/icon/icon.png`

Recommended:

- 1024×1024 PNG.
- Square.
- High resolution.
- Main artwork centered inside the Android safe area.

Splash source:

`assets/splash/6vitesses_splash.png`

Recommended:

- 1440×2560 PNG.
- Portrait.
- Main branding centered.

These assets will be connected to the native Android launcher and Android SplashScreen so the default Flutter branding is removed.

## Production hardening roadmap

### Phase A — Branding and startup

- [x] Launcher icon asset path.
- [x] Splash asset path.
- [ ] Wire `icon.png` into Android launcher resources.
- [ ] Configure adaptive launcher icon.
- [ ] Wire 6 VITESSES SplashScreen.
- [ ] Remove default Flutter launcher/startup branding.
- [ ] Verify cold start and warm start on Android 12+.
- [ ] Verify icon after release APK installation.

### Phase B — HUD layout validation

- [x] Preserve DIGITAL CLASSIC.
- [x] Preserve CIRCULAR.
- [x] Preserve LINEAR.
- [x] Add selectable DIGITAL GT.
- [x] Add NAV GT / SPORT GT / TOURING GT.
- [x] Add shared navigation/sign engine.
- [ ] Final NAV GT map placement validation.
- [ ] Final TOURING GT map placement validation.
- [ ] Verify Gear and STOP never overlap.
- [ ] Verify navigation never covers the speedometer.
- [ ] Verify mirror mode mirrors HUD content but keeps controls outside the mirrored layer.
- [ ] Validate different screen sizes.

### Phase C — Navigation production hardening

- [x] Automatic rerouting UX and retry messaging.
- [x] Arrival detection and destination completion.
- [x] Route refresh without losing HUD state.
- [x] Better route/network fallback.
- [x] Improve road-direction association from OSM geometry.
- [x] Improve speed-limit association with route segments.
- [x] Improve STOP / Give Way / traffic-light association.
- [x] Improve roundabout exit context.
- [x] Add parallel-road and crossing-road coverage tests.
- [x] Add service caching and retry policy.
- [x] Keep HUD usable when map services are unavailable.

### Phase D — Sensor fusion and performance

- [x] GPS + IMU fused speed/acceleration confidence.
- [x] GPS jump rejection with physically plausible movement filtering.
- [x] Sensor-noise confidence from filtered IMU residuals.
- [x] Explicit GPS / IMU / fused / unavailable source indicator.
- [x] Long-drive sensor workload instrumentation: callback count, average/max callback cost and event rate.
- [x] Long-session stability safeguards: bounded GPS jump handling, stale-source fallback and short IMU bridge without unbounded speed drift.
- [x] Sensor diagnostics expose confidence, rejected GPS jumps and workload counters.
- [ ] Physical battery-drain profiling on representative Android devices.

### Phase E — Driving performance features

- [ ] 0–60 measurement.
- [ ] 0–100 measurement.
- [ ] Maximum speed.
- [ ] Maximum acceleration.
- [ ] Maximum braking.
- [ ] Lateral G.
- [ ] Enriched trip statistics.
- [ ] Optional live OBD-II telemetry.

### Phase F — Final QA and release

- [ ] GPS permission matrix.
- [ ] IMU availability matrix.
- [ ] Lifecycle/background/resume validation.
- [ ] Screen rotation validation.
- [ ] City navigation test.
- [ ] Highway navigation test.
- [ ] Roundabout test.
- [ ] Parallel-road test.
- [ ] Network-loss test.
- [ ] Long-drive stability test.
- [ ] Final privacy/attribution review.
- [ ] Analyze.
- [ ] Flutter tests.
- [ ] Release APK.
- [ ] Release AAB.
- [ ] APK permission verification.

## CI

The main Android workflow runs:

1. `flutter analyze`
2. `flutter test`
3. Release APK build.
4. APK permission verification.
5. Release AAB build.
6. APK/AAB artifact upload.

The Android build verifies:

- INTERNET
- ACCESS_NETWORK_STATE
- ACCESS_FINE_LOCATION
- ACCESS_COARSE_LOCATION

**Signing configuration must not be changed during feature development.**

## Safe development rule

Every new change must preserve:

- Existing HUD styles.
- GPS permission flow.
- GPS reconnect/watchdog.
- IMU behavior.
- Landscape immersive HUD.
- Mirror mode.
- Automatic gear.
- History.
- Navigation state machine.
- Traffic-sign engine.
- Global search and route confirmation.
- Existing CI build and permission verification.

Changes should be small, testable commits. If a new feature breaks an existing working path, fix the regression before continuing.

## Next milestone

**Branding + startup, then final GT layout validation.**

Implementation order:

1. Connect the uploaded 6 VITESSES launcher icon.
2. Connect the 6 VITESSES SplashScreen.
3. Build and verify startup/icon without changing signing.
4. Validate NAV GT map position.
5. Validate TOURING GT map position.
6. Validate Gear/STOP spacing.
7. Run Analyze + Test + APK + AAB.
8. Only after this baseline is green, continue with navigation hardening and sensor fusion.

## Technical references

Flutter Android assets:
https://docs.flutter.dev/ui/assets/assets-and-images

Flutter Android splash screen:
https://docs.flutter.dev/platform-integration/android/splash-screen

Android SplashScreen:
https://developer.android.com/develop/ui/views/launch/splash-screen

---

**Repository:** `bdssmdkacem-dot/6-vitesses-`

**Product:** 6 VITESSES — DIGITAL GT

## Map tracking, turn signage & road speed limit (this update)

Three related driving-mode issues, all in the navigation HUD:

1. **Mini-map didn't track the drive.** The in-HUD map (`GtRouteMap`) always
   fit the *entire* route into view, so on any real route it stayed zoomed
   out and never followed the car. It now switches to a **"track-up" follow
   mode** once moving (≥5 km/h): the vehicle is anchored near the bottom of
   the widget, the road rotates so the direction of travel always points
   up, and only a local look-ahead window (160 m ahead / 55 m behind) is
   shown — the way turn-by-turn nav apps behave. It falls back to the old
   whole-route overview while stationary, when heading isn't reliable.
2. **Turn/traffic-sign badge was dead code.** `NavigationHudOverlay` already
   had a `trafficSign` slot to show the nearest sign next to the maneuver
   card, but the HUD screen never passed one in, so it never rendered.
   That's now wired up.
3. **No persistent road speed limit.** Speed-limit tags only ever showed up
   in the transient "upcoming signs" rail and vanished the instant the
   vehicle passed the sign, even though the limit still applied.
   `TrafficSignEngine.activeSpeedLimit()` now finds the most recently
   *passed* maxspeed tag along the route, and a permanent circular
   speed-limit badge stays on the HUD for that whole stretch of road,
   turning red if the driver goes more than 5 km/h over it.

New tests: `activeSpeedLimit reports the most recently passed maxspeed sign`
and `activeSpeedLimit returns null with no route context` in
`test/traffic_sign_engine_test.dart`.
