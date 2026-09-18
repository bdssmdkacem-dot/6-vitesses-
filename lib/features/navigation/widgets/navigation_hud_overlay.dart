import 'package:flutter/material.dart';
import '../navigation_models.dart';
import '../traffic_sign_engine.dart';

class NavigationHudOverlay extends StatelessWidget {
  const NavigationHudOverlay({super.key, required this.state, required this.accent, required this.secondary, this.trafficSign, this.message});
  final NavigationState state;
  final Color accent;
  final Color secondary;
  final RelevantTrafficSign? trafficSign;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final maneuver = state.nextManeuver;
    if (maneuver == null) return const SizedBox.shrink();
    return Positioned(
      top: 42, left: 0, right: 0,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(minWidth: 230, maxWidth: 430),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .58), borderRadius: BorderRadius.circular(18), border: Border.all(color: accent.withValues(alpha: .65))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _ManeuverIcon(type: maneuver.type, color: accent),
            const SizedBox(width: 12),
            Flexible(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (message != null) Text(message!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w900)),
              if (message != null) const SizedBox(height: 2),
              Text(_instruction(maneuver), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(_distance(maneuver.distanceMeters), style: TextStyle(color: secondary, fontSize: 12, fontWeight: FontWeight.w700)),
              if (maneuver.name != null && maneuver.name!.isNotEmpty) Text(maneuver.name!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ])),
            if (trafficSign != null) ...[
              const SizedBox(width: 10),
              _SignBadge(sign: trafficSign!, accent: accent),
            ],
            const SizedBox(width: 12),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_distance(state.remainingMeters), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              Text('${(state.remainingSeconds / 60).ceil()} min', style: TextStyle(color: secondary, fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }

  String _distance(double meters) => meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

  String _instruction(NavigationManeuver maneuver) {
    switch (maneuver.type) {
      case NavigationManeuverType.turnLeft: return 'TURN LEFT';
      case NavigationManeuverType.turnRight: return 'TURN RIGHT';
      case NavigationManeuverType.sharpLeft: return 'SHARP LEFT';
      case NavigationManeuverType.sharpRight: return 'SHARP RIGHT';
      case NavigationManeuverType.uTurn: return 'U-TURN';
      case NavigationManeuverType.roundabout: return maneuver.exitNumber == null ? 'ROUNDABOUT' : 'ROUNDABOUT · EXIT ${maneuver.exitNumber}';
      case NavigationManeuverType.merge: return 'MERGE';
      case NavigationManeuverType.fork: return 'KEEP ${_side(maneuver.modifier)}';
      case NavigationManeuverType.offRamp: return 'EXIT';
      case NavigationManeuverType.onRamp: return 'ON RAMP';
      case NavigationManeuverType.endOfRoad: return 'END OF ROAD';
      case NavigationManeuverType.arrive: return 'ARRIVE';
      case NavigationManeuverType.depart: return 'START';
      case NavigationManeuverType.straight: return 'STRAIGHT';
      case NavigationManeuverType.unknown: return 'CONTINUE';
    }
  }
  String _side(String? value) => value == 'left' ? 'LEFT' : value == 'right' ? 'RIGHT' : 'STRAIGHT';
}

class _ManeuverIcon extends StatelessWidget {
  const _ManeuverIcon({required this.type, required this.color});
  final NavigationManeuverType type;
  final Color color;
  @override Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case NavigationManeuverType.turnLeft:
      case NavigationManeuverType.sharpLeft: icon = Icons.turn_left;
      case NavigationManeuverType.turnRight:
      case NavigationManeuverType.sharpRight: icon = Icons.turn_right;
      case NavigationManeuverType.uTurn: icon = Icons.u_turn_left;
      case NavigationManeuverType.roundabout: icon = Icons.roundabout_left;
      case NavigationManeuverType.arrive: icon = Icons.flag;
      default: icon = Icons.straight;
    }
    return Icon(icon, color: color, size: 42);
  }
}

class _SignBadge extends StatelessWidget {
  const _SignBadge({required this.sign, required this.accent});
  final RelevantTrafficSign sign;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = switch (sign.sign.type) {
      TrafficSignType.stop => 'STOP',
      TrafficSignType.giveWay => 'GIVE WAY',
      TrafficSignType.speedLimit => sign.sign.value == null ? 'SPEED' : '${sign.sign.value}',
      TrafficSignType.trafficSignals => 'LIGHTS',
      TrafficSignType.roundabout => 'ROUND',
      TrafficSignType.crossing => 'CROSS',
      TrafficSignType.motorway => 'MOTORWAY',
      TrafficSignType.oneWay => 'ONE WAY',
      TrafficSignType.unknown => 'ROAD',
    };
    final icon = switch (sign.sign.type) {
      TrafficSignType.stop => Icons.stop_circle,
      TrafficSignType.giveWay => Icons.change_history,
      TrafficSignType.speedLimit => Icons.speed,
      TrafficSignType.trafficSignals => Icons.traffic,
      TrafficSignType.roundabout => Icons.roundabout_left,
      TrafficSignType.crossing => Icons.person,
      TrafficSignType.motorway => Icons.directions_car,
      TrafficSignType.oneWay => Icons.arrow_forward,
      TrafficSignType.unknown => Icons.info_outline,
    };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: accent, size: 28),
      Text(label, style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w900)),
      Text('${sign.distanceMeters.round()}m', style: const TextStyle(color: Colors.white, fontSize: 8)),
    ]);
  }
}
