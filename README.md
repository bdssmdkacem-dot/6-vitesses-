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

- [ ] Automatic rerouting UX and retry messaging.
- [ ] Arrival detection and destination completion.
- [ ] Route refresh without losing HUD state.
- [ ] Better route/network fallback.
- [ ] Improve road-direction association from OSM geometry.
- [ ] Improve speed-limit association with route segments.
- [ ] Improve STOP / Give Way / traffic-light association.
- [ ] Improve roundabout exit context.
- [ ] Add parallel-road and crossing-road coverage tests.
- [ ] Add service caching and retry policy.
- [ ] Keep HUD usable when map services are unavailable.

### Phase D — Sensor fusion and performance

- [ ] GPS + IMU fused speed/acceleration confidence.
- [ ] GPS jump rejection.
- [ ] Sensor-noise confidence.
- [ ] Explicit GPS / IMU / fused source indicator.
- [ ] Battery/performance profiling during long drives.
- [ ] Long-session memory/stability validation.

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
