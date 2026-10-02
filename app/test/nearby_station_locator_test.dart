import 'dart:async';

import 'package:detro/services/nearby_station_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Fake extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  _Fake({
    this.fixes = const [],
    this.lastKnown,
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
  });

  final List<Position> fixes;

  final Position? lastKnown;
  final bool serviceEnabled;
  final LocationPermission permission;

  int calls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
    Duration? timeLimit,
  }) async {
    final index = calls < fixes.length ? calls : fixes.length - 1;
    calls++;
    if (fixes.isEmpty) throw TimeoutException('no signal');
    return fixes[index];
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => lastKnown;
}

Position _pos(double lat, double lon, {int daysOld = 0}) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime.now().toUtc().subtract(Duration(days: daysOld)),
  accuracy: 11.97,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

final _recycledHeliopolis = _pos(29.972411, 31.324929, daysOld: 6);
final _zahraa = _pos(29.995278, 31.231667);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('picks the closest station to a good fix', () async {
    GeolocatorPlatform.instance = _Fake(fixes: [_zahraa]);
    final result = await NearbyStationLocator().nearestStation();

    expect(result.isSuccess, isTrue);
    expect(result.station!.station, 'elzahraa');
    expect(result.station!.distanceMeters, lessThan(50));
  });

  test('accepts a distant reading rather than refusing to answer', () async {
    GeolocatorPlatform.instance = _Fake(fixes: [_recycledHeliopolis]);
    final result = await NearbyStationLocator().nearestStation();

    expect(result.isSuccess, isTrue);
    expect(result.station!.station, 'toraelbalad');
    expect(
      result.station!.distanceMeters,
      closeTo(5730, 200),
      reason: 'kept as-is: no distance gate',
    );
  });

  test('accepts a reading with terrible accuracy', () async {
    GeolocatorPlatform.instance = _Fake(
      fixes: [
        Position(
          latitude: 29.995278,
          longitude: 31.231667,
          timestamp: DateTime.now().toUtc(),
          accuracy: 5000,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      ],
    );
    final result = await NearbyStationLocator().nearestStation();

    expect(result.isSuccess, isTrue);
    expect(result.station!.station, 'elzahraa');
  });

  test('falls back to the last known position when nothing is live', () async {
    GeolocatorPlatform.instance = _Fake(
      fixes: const [],
      lastKnown: _recycledHeliopolis,
    );
    final result = await NearbyStationLocator().nearestStation();

    expect(result.isSuccess, isTrue);
    expect(result.station!.station, 'toraelbalad');
  });

  test('reports no fix when the device has no position at all', () async {
    GeolocatorPlatform.instance = _Fake(fixes: const []);
    final result = await NearbyStationLocator().nearestStation();

    expect(result.isSuccess, isFalse);
    expect(result.failure, LocateFailure.noFix);
  });

  test('reports disabled location service', () async {
    GeolocatorPlatform.instance = _Fake(serviceEnabled: false);
    final result = await NearbyStationLocator().nearestStation();

    expect(result.failure, LocateFailure.serviceDisabled);
  });

  test('reports permanently denied permission', () async {
    GeolocatorPlatform.instance = _Fake(
      permission: LocationPermission.deniedForever,
    );
    final result = await NearbyStationLocator().nearestStation();

    expect(result.failure, LocateFailure.permissionDeniedForever);
  });
}