# 6 VITESSES — DIGITAL GT

Android Flutter driving dashboard / HUD.

> GPS regression rollback baseline: restored to the last known working pre-Phase-E state (2026-09-19 15:47 UTC).

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

## Navigation architecture

`GPS / OSRM → Navigation Engine → Traffic / Sign Engine → Navigation HUD Overlay → Mirror Layer`

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

## Production hardening roadmap

### Phase D — Sensor fusion and performance

- [x] GPS + IMU fused speed/acceleration confidence.
- [x] GPS jump rejection with physically plausible movement filtering.
- [x] Sensor-noise confidence from filtered IMU residuals.
- [x] Explicit GPS / IMU / fused / unavailable source indicator.
- [x] Long-drive sensor workload instrumentation.
- [x] Long-session stability safeguards.
- [x] Sensor diagnostics.

### Phase E — Driving performance features

- [x] 0–60 measurement.
- [x] 0–100 measurement.
- [x] Maximum speed.
- [x] Maximum acceleration.
- [x] Maximum braking.
- [x] Lateral G.
- [x] Enriched trip statistics.
- [ ] Physical OBD-II adapter validation.

## CI

The main Android workflow runs:

1. `flutter analyze`
2. `flutter test`
3. Release APK build.
4. APK permission verification.
5. Release AAB build.
6. APK/AAB artifact upload.

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
