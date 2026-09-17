import 'package:flutter/material.dart';

enum HudGaugeStyle { digital, circular, linear }

class HudTheme {
  const HudTheme({required this.name,required this.background,required this.accent,required this.secondary});
  final String name; final Color background, accent, secondary;
  static const midnight=HudTheme(name:'Midnight',background:Color(0xFF050505),accent:Color(0xFF00E5FF),secondary:Color(0xFF607D8B));
  static const amber=HudTheme(name:'Amber',background:Color(0xFF080604),accent:Color(0xFFFFB300),secondary:Color(0xFF795548));
  static const redline=HudTheme(name:'Redline',background:Color(0xFF080303),accent:Color(0xFFFF3D00),secondary:Color(0xFF8D6E63));
  static const ice=HudTheme(name:'Ice',background:Color(0xFF03070A),accent:Color(0xFF80DEEA),secondary:Color(0xFF546E7A));
  static const neon=HudTheme(name:'Neon',background:Color(0xFF050208),accent:Color(0xFFE040FB),secondary:Color(0xFF7E57C2));
  static const all=[midnight,amber,redline,ice,neon];
}