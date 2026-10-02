
import 'package:detro/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Fake extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  final Position fix;
  _Fake(this.fix);
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
    Duration? timeLimit,
  }) async => fix;
  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => null;
}

void main() {
  testWidgets('detected station appears in the start field', (tester) async {
    GeolocatorPlatform.instance = _Fake(Position(
      latitude: 29.972411, longitude: 31.324929,
      timestamp: DateTime.now().toUtc(), accuracy: 12,
      altitude: 0, altitudeAccuracy: 0, heading: 0,
      headingAccuracy: 0, speed: 0, speedAccuracy: 0));

    await tester.pumpWidget(const DetroApp());
    await tester.pumpAndSettle();

    final before = tester
        .widgetList<TextField>(find.byType(TextField))
        .first
        .controller
        ?.text ??
        '';
    expect(before, isEmpty, reason: 'starts empty');

    await tester.tap(find.byTooltip('Detect nearest station'));
    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    final startText = fields.first.controller?.text ?? '';
    expect(startText, isNotEmpty, reason: 'start field must show the station');
    expect(startText, 'Tora El-Balad');
  });
}
