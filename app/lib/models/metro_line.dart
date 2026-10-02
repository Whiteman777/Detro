import 'station.dart';

class MetroLine {
  final String name;
  final List<Station> stations;
  final double headwayMinutes;
  final double segmentMinutes;

  const MetroLine({
    required this.name,
    required this.stations,
    this.headwayMinutes = 3,
    this.segmentMinutes = 2.0,
  });
}
