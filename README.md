# 6 Vitesses

Flutter Android HUD / driving dashboard.

## Milestone 1
GPS speed, GPS status, acceleration magnitude, maximum speed, maximum acceleration, landscape immersive HUD, keep-awake display and mirror mode.

## Roadmap
1. GPS + acceleration + mirror HUD
2. filtering and sensor calibration
3. digital / circular / linear gauges
4. themes and backgrounds
5. driving sessions and statistics
6. compass / altitude / GPS quality
7. optional OBD-II
8. Android tests, APK and AAB

Open-source speedometer, HUD, dashboard and sensor projects are used as technical references; this application is implemented separately.


## Production Architecture — v0.2.0

The app is now organized around independent production layers:

- **HUD:** GPS speed, smoothing, stale-data watchdog, acceleration, themes, mirror mode and manual gear display.
- **Persistent settings:** vehicle profile, speed unit, gauge range, theme, mirror, gear and OBD preference are stored locally.
- **Driving domain:** each completed drive is finalized as an immutable `DriveRecord`.
- **History:** up to 50 completed drives are stored locally and can be reviewed or cleared.
- **Sensors:** GPS is the primary vehicle-speed source; the phone accelerometer provides total G-force. GPS loss forces the displayed speed/longitudinal acceleration to zero.
- **OBD-II architecture:** `ObdAdapter` is transport-neutral, while `ObdTransport` and `Elm327Session` isolate Bluetooth/ELM327 communication from the HUD. The parser supports standard PIDs for engine load, coolant, RPM, vehicle speed and throttle.
- **Fallback:** OBD-II is optional; the application remains usable with GPS when no adapter is connected.
- **Lifecycle:** immersive landscape HUD and screen wake state are restored when the app resumes; drive controls remain locked while a drive is active.
- **CI:** every main-branch build runs analyze + tests and produces both release APK and AAB artifacts.

### Remaining production gates

1. Implement a real Android Bluetooth transport for supported ELM327 adapters.
2. Add Android Bluetooth permissions and adapter discovery only when OBD is enabled.
3. Add release signing/keystore configuration for Play-ready AAB delivery.
4. Add device-matrix validation for GPS, sensor availability, lifecycle and Bluetooth failures.
5. Add final application icon, store metadata and privacy disclosures.


## Release signing

Release signing is designed for GitHub Actions without committing secrets:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded release keystore.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: signing key alias.
- `ANDROID_KEY_PASSWORD`: signing key password.

The CI workflow must decode the keystore only on the runner and configure the generated Android project from these secrets. No keystore, password, or signing key is stored in Git.

**Important:** the repository does not contain a signing key yet. The final Play-ready AAB therefore requires the owner's existing release keystore or a newly generated one to be stored as GitHub Actions secrets. If the Play Console app is already associated with an upload key, keep that key and do not replace it casually.


## Production-grade navigation status

The prototype navigation flow is now being hardened into a production-oriented driving/navigation stack.

### Completed navigation foundation

- [x] GPS speed and heading acquisition with permission/reconnect handling.
- [x] Responsive IMU acceleration and braking measurement.
- [x] Route model with OSRM driving geometry and turn-by-turn maneuver metadata.
- [x] Route projection with cross-track distance, route progress and segment continuity.
- [x] Maneuver progression and live distance to the next maneuver.
- [x] Navigation guidance rendered directly in the HUD.
- [x] Global place search with destination confirmation.
- [x] Search → route → START → HUD navigation flow.
- [x] Route-aware traffic-sign filtering.
- [x] Explicit navigation session state machine: idle, navigating, off-route, rerouting and arrived.
- [x] Sustained off-route detection before rerouting.
- [x] Reroute cooldown and network-failure preservation of the current navigation session.
- [x] Traffic-sign heading filtering uses vehicle speed to determine heading confidence.
- [x] Analyze + tests + release APK + release AAB + APK permission verification in CI.

### Current production hardening queue

1. **Navigation reliability**
   - [ ] automatic rerouting UX and retry messaging
   - [ ] arrival handling and destination completion
   - [ ] route/network failure fallback
   - [ ] route refresh without losing HUD state
   - [ ] navigation session persistence where appropriate

2. **Traffic intelligence**
   - [ ] derive road direction from OSM geometry
   - [ ] associate speed limits with the correct route segment
   - [ ] improve STOP / Give Way / traffic-light association
   - [ ] improve roundabout exit context
   - [ ] add coverage tests for signs on parallel and crossing roads

3. **Sensor fusion**
   - [ ] GPS + IMU fused speed/acceleration confidence
   - [ ] GPS jump rejection
   - [ ] sensor-noise confidence
   - [ ] explicit GPS / IMU / fused source indicator

4. **Map and routing production services**
   - [ ] replace hard dependency on public demo routing for production traffic
   - [ ] make map tile provider configurable
   - [ ] choose a production geocoder/routing provider or self-host the OSM stack
   - [ ] caching and network retry policy
   - [ ] offline-safe HUD behavior when map services are unavailable

5. **Driving features**
   - [ ] 0–100 and 0–60 measurements
   - [ ] maximum speed / acceleration / braking / lateral G
   - [ ] trip statistics and history enrichment
   - [ ] OBD-II live telemetry when an adapter is connected

6. **Final QA**
   - [ ] device matrix: GPS, IMU, lifecycle and screen rotation
   - [ ] long-drive stability test
   - [ ] route tests in city, highway, roundabout and parallel-road scenarios
   - [ ] final Play Store privacy/attribution review
   - [ ] production release validation

> Release signing is intentionally not part of this hardening pass. Existing signing configuration must remain untouched.
