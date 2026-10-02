import '../models/metro_line.dart';
import '../models/station.dart';

class ElMounibLine extends MetroLine {
  const ElMounibLine()
    : super(
        name: "elmounib",
        stations: elMounibStations,
        headwayMinutes: 3,
        segmentMinutes: 2.0,
      );

  static const List<Station> elMounibStations = [
    Station(name: 'Shubra El-Kheima', order: 1, isTransitional: false),
    Station(name: 'Kolleyyet El-Zeraa', order: 2, isTransitional: false),
    Station(name: 'Mezallat', order: 3, isTransitional: false),
    Station(name: 'Khalafawy', order: 4, isTransitional: false),
    Station(name: 'St. Teresa', order: 5, isTransitional: false),
    Station(name: 'Road El-Farag', order: 6, isTransitional: false),
    Station(name: 'Masarra', order: 7, isTransitional: false),
    Station(name: 'Al-Shohadaa', order: 8, isTransitional: true),
    Station(name: 'Attaba', order: 9, isTransitional: true),
    Station(name: 'Mohamed Naguib', order: 10, isTransitional: false),
    Station(name: 'Sadat', order: 11, isTransitional: true),
    Station(name: 'Opera', order: 12, isTransitional: false),
    Station(name: 'Dokki', order: 13, isTransitional: false),
    Station(name: 'El Bohoth', order: 14, isTransitional: false),
    Station(name: 'Cairo University', order: 15, isTransitional: true),
    Station(name: 'Faisal', order: 16, isTransitional: false),
    Station(name: 'El Giza', order: 17, isTransitional: false),
    Station(name: 'Omm El-Masryeen', order: 18, isTransitional: false),
    Station(name: 'Sakiat Mekky', order: 19, isTransitional: false),
    Station(name: 'El-Mounib', order: 20, isTransitional: false),
  ];
}
