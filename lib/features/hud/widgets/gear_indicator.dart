import 'package:flutter/material.dart';
import '../models/hud_theme.dart';

class GearIndicator extends StatelessWidget {
  const GearIndicator({
    super.key,
    required this.gear,
    required this.theme,
    this.enabled = true,
  });

  final int gear;
  final HudTheme theme;
  final bool enabled;

  String get label => gear == 0 ? 'N' : gear.toString();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'GEAR',
          style: TextStyle(
            color: theme.secondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: enabled ? theme.accent : theme.secondary,
            fontSize: 54,
            fontWeight: FontWeight.w900,
            height: .9,
          ),
        ),
      ],
    );
  }
}
