import 'package:flutter/material.dart';

enum HudGaugeStyle { digital, digitalGt, circular, linear }
enum GtLayout { nav, sport, touring }
enum HudBackgroundStyle { solid, carbon, grid, road, night }
enum HudRpmStyle { arc, bars, strip }

class HudTheme {
  const HudTheme({
    required this.name,
    required this.background,
    required this.accent,
    required this.secondary,
    this.backgroundStyle = HudBackgroundStyle.solid,
    this.defaultGauge = HudGaugeStyle.digital,
    this.rpmStyle = HudRpmStyle.arc,
    this.showRpm = true,
    this.glow = false,
    this.motionFactor = 1.0,
  });
  final String name;
  final Color background;
  final Color accent;
  final Color secondary;
  final HudBackgroundStyle backgroundStyle;
  final HudGaugeStyle defaultGauge;
  final HudRpmStyle rpmStyle;
  final bool showRpm;
  final bool glow;
  final double motionFactor;

  static const midnight = HudTheme(name:'Midnight',background:Color(0xFF050505),accent:Color(0xFF00E5FF),secondary:Color(0xFF607D8B),backgroundStyle:HudBackgroundStyle.solid,defaultGauge:HudGaugeStyle.digital,rpmStyle:HudRpmStyle.arc,glow:true,motionFactor:.8);
  static const amber = HudTheme(name:'Amber',background:Color(0xFF080604),accent:Color(0xFFFFB300),secondary:Color(0xFF795548),backgroundStyle:HudBackgroundStyle.road,defaultGauge:HudGaugeStyle.circular,rpmStyle:HudRpmStyle.strip,glow:true,motionFactor:1.15);
  static const redline = HudTheme(name:'Redline',background:Color(0xFF080303),accent:Color(0xFFFF3D00),secondary:Color(0xFF8D6E63),backgroundStyle:HudBackgroundStyle.carbon,defaultGauge:HudGaugeStyle.circular,rpmStyle:HudRpmStyle.bars,glow:true,motionFactor:1.35);
  static const ice = HudTheme(name:'Ice',background:Color(0xFF03070A),accent:Color(0xFF80DEEA),secondary:Color(0xFF546E7A),backgroundStyle:HudBackgroundStyle.grid,defaultGauge:HudGaugeStyle.linear,rpmStyle:HudRpmStyle.strip,glow:false,motionFactor:.65);
  static const neon = HudTheme(name:'Neon',background:Color(0xFF050208),accent:Color(0xFFE040FB),secondary:Color(0xFF7E57C2),backgroundStyle:HudBackgroundStyle.grid,defaultGauge:HudGaugeStyle.digital,rpmStyle:HudRpmStyle.arc,glow:true,motionFactor:1.5);
  static const all = [midnight, amber, redline, ice, neon];
}
