import '../models/metro_line.dart';
import '../models/station.dart';

class ElMargLine extends MetroLine {
  const ElMargLine()
      : super(
          name: "elmarg",
          stations: elMargStations,
          headwayMinutes: 2.5,
          segmentMinutes: 2.0,
        );

  static const List<Station> elMargStations = [
    Station(name: 'New El-Marg', order: 1, isTransitional: false),
    Station(name: 'El-Marg', order: 2, isTransitional: false),
    Station(name: 'Ezbet El-Nakhl', order: 3, isTransitional: false),
    Station(name: 'Ain Shams', order: 4, isTransitional: false),
    Station(name: 'El-Matareyya', order: 5, isTransitional: false),
    Station(name: 'Helmeyet El-Zaitoun', order: 6, isTransitional: false),
    Station(name: 'Hadayeq El-Zaitoun', order: 7, isTransitional: false),
    Station(name: 'Saray El-Qobba', order: 8, isTransitional: false),
    Station(name: 'Hammamat El-Qobba', order: 9, isTransitional: false),
    Station(name: 'Kobri El-Qobba', order: 10, isTransitional: false),
    Station(name: 'Manshiet El-Sadr', order: 11, isTransitional: false),
    Station(name: 'El-Demerdash', order: 12, isTransitional: false),
    Station(name: 'Ghamra', order: 13, isTransitional: false),
    Station(name: 'Al-Shohadaa', order: 14, isTransitional: true),
    Station(name: 'Orabi', order: 15, isTransitional: false),
    Station(name: 'Nasser', order: 16, isTransitional: true),
    Station(name: 'Sadat', order: 17, isTransitional: true),
    Station(name: 'Saad Zaghloul', order: 18, isTransitional: false),
    Station(name: 'Al-Sayeda Zeinab', order: 19, isTransitional: false),
    Station(name: 'El-Malek El-Saleh', order: 20, isTransitional: false),
    Station(name: 'Mar Girgis', order: 21, isTransitional: false),
    Station(name: 'El-Zahraa', order: 22, isTransitional: false),
    Station(name: 'Dar El-Salam', order: 23, isTransitional: false),
    Station(name: 'Hadayek El-Maadi', order: 24, isTransitional: false),
    Station(name: 'Maadi', order: 25, isTransitional: false),
    Station(name: 'Sakanat El-Maadi', order: 26, isTransitional: false),
    Station(name: 'Tora El-Balad', order: 27, isTransitional: false),
    Station(name: 'Kozzika', order: 28, isTransitional: false),
    Station(name: 'Tora El-Asmant', order: 29, isTransitional: false),
    Station(name: 'El-Maasara', order: 30, isTransitional: false),
    Station(name: 'Hadayek Helwan', order: 31, isTransitional: false),
    Station(name: 'Wadi Hof', order: 32, isTransitional: false),
    Station(name: 'Helwan University', order: 33, isTransitional: false),
    Station(name: 'Ain Helwan', order: 34, isTransitional: false),
    Station(name: 'Helwan', order: 35, isTransitional: false),
  ];
}
