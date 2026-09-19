import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/features/hud/models/hud_theme.dart';
import 'package:six_vitesses/features/hud/widgets/gt_layout_engine.dart';

void main() {
  test('NAV GT reserves map, full navigation data and full sign rail', () {
    final spec = GtLayoutEngine.spec(GtLayout.nav);

    expect(spec.showMap, isTrue);
    expect(spec.showFullSignRail, isTrue);
    expect(spec.showGForce, isFalse);
    expect(spec.showTrip, isTrue);
    expect(spec.showEta, isTrue);
    expect(spec.showRoadName, isTrue);
    expect(spec.compactNavigation, isFalse);
    expect(GtLayoutEngine.label(GtLayout.nav), 'NAV GT');
  });

  test('TOURING GT keeps map and long-drive telemetry', () {
    final spec = GtLayoutEngine.spec(GtLayout.touring);

    expect(spec.showMap, isTrue);
    expect(spec.showFullSignRail, isTrue);
    expect(spec.showGForce, isTrue);
    expect(spec.showTrip, isTrue);
    expect(spec.showEta, isTrue);
    expect(spec.showRoadName, isTrue);
    expect(spec.compactNavigation, isFalse);
    expect(GtLayoutEngine.label(GtLayout.touring), 'TOURING GT');
  });

  test('SPORT GT remains map-free and compact', () {
    final spec = GtLayoutEngine.spec(GtLayout.sport);

    expect(spec.showMap, isFalse);
    expect(spec.showFullSignRail, isFalse);
    expect(spec.showGForce, isTrue);
    expect(spec.showTrip, isFalse);
    expect(spec.showEta, isFalse);
    expect(spec.showRoadName, isFalse);
    expect(spec.compactNavigation, isTrue);
    expect(GtLayoutEngine.label(GtLayout.sport), 'SPORT GT');
  });

  test('all GT layouts are exposed', () {
    expect(GtLayout.values, containsAll(<GtLayout>[
      GtLayout.nav,
      GtLayout.sport,
      GtLayout.touring,
    ]));
  });
}
