import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../data/station_coordinates.dart';

enum LocateFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  noFix,
  unavailable,
}

class LocateResult {
  const LocateResult.success(this.station, {this.accuracyMeters})
    : failure = null;

  const LocateResult.failed(this.failure) : station = null, accuracyMeters = null;

  final NearbyStation? station;

  final LocateFailure? failure;

  final double? accuracyMeters;

  bool get isSuccess => station != null;
}

class NearbyStationLocator {
  static const Duration fixTimeout = Duration(seconds: 20);

  static const Duration locationManagerTimeout = Duration(seconds: 10);

  static const Duration timeoutSlack = Duration(seconds: 2);

  Future<LocateResult> nearestStation() async {
    final serviceEnabled = await _isServiceEnabled();
    if (serviceEnabled != true) {
      return LocateResult.failed(
        serviceEnabled == false
            ? LocateFailure.serviceDisabled
            : LocateFailure.unavailable,
      );
    }

    final permissionFailure = await _resolvePermission();
    if (permissionFailure != null) {
      return LocateResult.failed(permissionFailure);
    }

    final position = await _currentPosition();
    if (position == null) {
      final cached = await _lastKnownPosition();
      if (cached != null) return _stationNear(cached);
      return const LocateResult.failed(LocateFailure.noFix);
    }

    return _stationNear(position);
  }

  LocateResult _stationNear(Position position) {
    final station = NearbyStation.nearestTo(position.latitude, position.longitude);
    if (station == null) {
      return const LocateResult.failed(LocateFailure.unavailable);
    }
    debugPrint(
      'nearest ${station.station} at ${station.distanceMeters.round()}m '
      '(accuracy ${position.accuracy.round()}m)',
    );
    return LocateResult.success(station, accuracyMeters: position.accuracy);
  }

  Future<Position?> _currentPosition() async {
    for (final settings in _fixStrategies()) {
      final position = await _attemptFix(settings);
      if (position != null) return position;
    }
    return null;
  }

  Iterable<LocationSettings> _fixStrategies() sync* {
    yield _settings(accuracy: LocationAccuracy.high, timeout: fixTimeout);
    yield _settings(
      accuracy: LocationAccuracy.medium,
      timeout: locationManagerTimeout,
      forceLocationManager: true,
    );
  }

  LocationSettings _settings({
    required LocationAccuracy accuracy,
    required Duration timeout,
    bool forceLocationManager = false,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        timeLimit: timeout,
        forceLocationManager: forceLocationManager,
      );
    }
    return LocationSettings(accuracy: accuracy, timeLimit: timeout);
  }

  Future<Position?> _attemptFix(LocationSettings settings) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(
        (settings.timeLimit ?? fixTimeout) + timeoutSlack,
        onTimeout: () => throw TimeoutException('fix deadline exceeded'),
      );
    } on TimeoutException {
      debugPrint('no fix from ${settings.accuracy}');
    } on PositionUpdateException catch (e) {
      debugPrint('position update failed: ${e.message}');
    } on LocationServiceDisabledException {
      debugPrint('location service switched off while acquiring a fix');
    } on PlatformException catch (e) {
      debugPrint('getCurrentPosition failed: ${e.code} ${e.message}');
    } on MissingPluginException {
      debugPrint('geolocator plugin missing');
    } on Object catch (e) {
      debugPrint('unexpected location error: $e');
    }
    return null;
  }

  Future<Position?> _lastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } on Object catch (e) {
      debugPrint('getLastKnownPosition failed: $e');
      return null;
    }
  }

  Future<bool?> _isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('isLocationServiceEnabled failed: ${e.code} ${e.message}');
      return null;
    }
  }

  Future<LocateFailure?> _resolvePermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return null;
        case LocationPermission.deniedForever:
          return LocateFailure.permissionDeniedForever;
        case LocationPermission.denied:
          return LocateFailure.permissionDenied;
        case LocationPermission.unableToDetermine:
          return LocateFailure.unavailable;
      }
    } on PermissionRequestInProgressException {
      return LocateFailure.permissionDenied;
    } on PlatformException catch (e) {
      debugPrint('permission check failed: ${e.code} ${e.message}');
      return LocateFailure.unavailable;
    } on MissingPluginException {
      return LocateFailure.unavailable;
    }
  }
}

class NearbyStation {
  const NearbyStation({
    required this.station,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });

  static NearbyStation? nearestTo(double latitude, double longitude) {
    NearbyStation? best;
    for (final entry in stationCoordinates.entries) {
      final (stationLat, stationLon) = entry.value;
      final distance = _distanceMeters(latitude, longitude, stationLat, stationLon);
      if (best == null || distance < best.distanceMeters) {
        best = NearbyStation(
          station: entry.key,
          latitude: stationLat,
          longitude: stationLon,
          distanceMeters: distance,
        );
      }
    }
    return best;
  }

  static double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;

  final String station;
  final double latitude;
  final double longitude;
  final double distanceMeters;
}