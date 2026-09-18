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


## HUD Design — Current

The production HUD is now focused on a clean landscape automotive dashboard before navigation integration:

- Five local presets: **Sport, Daily, Night, Windshield and Performance**.
- Three speed presentations: **Digital, Circular and Linear**.
- Circular and linear gauges include graduated scales, a moving marker and speed-range indication.
- Digital mode includes a compact progress scale beneath the primary speed readout.
- Speed-limit badge and overspeed indication are available on the main HUD.
- Live acceleration uses the high-rate phone IMU; GPS remains authoritative for vehicle speed and drive-session samples.
- GPS quality/loss, G-force, maximum speed, braking maximum, trip distance, RPM and manual gear remain available according to the selected layout.
- Windshield mode uses a strict horizontal mirror transform and a compact information layout for reflection on glass.
- Preset and HUD settings persist locally with SharedPreferences.
- Navigation is intentionally **deferred**. The future navigation layer will be isolated from the HUD so Google Maps/Waze integration does not change the dashboard rendering architecture.

### Next HUD validation gate

Validate the five presets on a real landscape Android device, including daylight/night readability, touch controls before driving, mirror reflection on windshield glass, GPS loss behavior and sensor responsiveness. Only after this visual/device gate is complete should the Navigation layer be introduced.

## Release signing

Release signing is designed for GitHub Actions without committing secrets:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded release keystore.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: signing key alias.
- `ANDROID_KEY_PASSWORD`: signing key password.

The CI workflow must decode the keystore only on the runner and configure the generated Android project from these secrets. No keystore, password, or signing key is stored in Git.

**Important:** the repository does not contain a signing key yet. The final Play-ready AAB therefore requires the owner's existing release keystore or a newly generated one to be stored as GitHub Actions secrets. If the Play Console app is already associated with an upload key, keep that key and do not replace it casually.


Production HUD branch: `production-hud`.
