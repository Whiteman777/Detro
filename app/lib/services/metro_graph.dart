import '../data/travel_times.dart';
import '../models/metro_line.dart';
import '../utils/normalize.dart';

enum GateMode { comfortable, fastest }

const double transferDwellMinutes = 6.0;

const double _transferPenaltyStops = 10000.0;

class MetroGraph {
  late final List<MetroLine> _lines;
  final Map<String, Set<String>> _neighbors = {};
  final Map<String, String> _displayNames = {};
  final Set<String> _transfers = {};

  MetroGraph(List<MetroLine> lines) {
    _lines = lines;
    for (final line in lines) {
      final stations = line.stations;
      for (var i = 0; i < stations.length; i++) {
        final current = normalize(stations[i].name);
        if (_displayNames.containsKey(current)) {
          _transfers.add(current);
        }
        _displayNames.putIfAbsent(current, () => stations[i].name);
        _neighbors.putIfAbsent(current, () => <String>{});

        if (i > 0) _neighbors[current]!.add(normalize(stations[i - 1].name));
        if (i < stations.length - 1) {
          _neighbors[current]!.add(normalize(stations[i + 1].name));
        }
      }
    }
  }

  List<String> get stations {
    final names = _displayNames.values.toList()..sort();
    return names;
  }

  String? find(String input) {
    final key = normalize(input);
    return _neighbors.containsKey(key) ? key : null;
  }

  bool isTransfer(String displayName) =>
      _transfers.contains(normalize(displayName));

  bool needsChange(List<String> path, int index) {
    if (index < 1 || index >= path.length - 1) return false;
    final inLine = lineOfSegment(path[index - 1], path[index]);
    final outLine = lineOfSegment(path[index], path[index + 1]);
    return inLine != null && outLine != null && inLine.name != outLine.name;
  }

  String? switchLine(List<String> path, int index) {
    if (index < 1 || index >= path.length - 1) return null;
    final inLine = lineOfSegment(path[index - 1], path[index]);
    final outLine = lineOfSegment(path[index], path[index + 1]);
    if (inLine == null || outLine == null || inLine.name == outLine.name) {
      return null;
    }
    return lineLabel(outLine);
  }

  String lineLabel(MetroLine line) => switch (line.name) {
    'elmarg' => 'Line 1',
    'elmounib' => 'Line 2',
    'rodelfarag' || 'cairoUniversity' => 'Line 3',
    _ => line.name,
  };

  MetroLine? lineOfSegment(String a, String b) {
    for (final line in _lines) {
      final orders = <String, int>{};
      for (final s in line.stations) {
        orders[normalize(s.name)] = s.order;
      }
      final oa = orders[normalize(a)];
      final ob = orders[normalize(b)];
      if (oa != null && ob != null && (oa - ob).abs() == 1) {
        return line;
      }
    }
    return null;
  }

  List<String> displayRoute(List<String> path) {
    if (path.length <= 5) return _withChangeMarkers(path);

    final show = <int>{0, 1, path.length - 2, path.length - 1};
    for (var i = 0; i < path.length; i++) {
      if (needsChange(path, i)) {
        show.add(i);
        if (i + 1 < path.length) show.add(i + 1);
      }
    }

    final sorted = show.toList()..sort();
    final result = <String>[];
    var last = -1;
    for (final i in sorted) {
      if (result.isNotEmpty && i > last + 1) result.add('...');
      result.add(path[i] + (needsChange(path, i) ? ' (change)' : ''));
      last = i;
    }
    return result;
  }

  List<String> _withChangeMarkers(List<String> path) {
    return [
      for (var i = 0; i < path.length; i++)
        path[i] + (needsChange(path, i) ? ' (change)' : ''),
    ];
  }

  List<String> shortestPath(String start, String stop) =>
      shortestTrip(start, stop).stations;

  TripRoute shortestTrip(
    String start,
    String stop, {
    GateMode gateMode = GateMode.comfortable,
  }) {
    if (start == stop) {
      return TripRoute(
        stations: [_displayNames[start]!],
        hops: 0,
        transfers: 0,
        minutes: 0,
      );
    }

    final ordersByLine = <MetroLine, Map<String, int>>{
      for (final line in _lines)
        line: {for (final s in line.stations) normalize(s.name): s.order},
    };

    final linesOf = <String, Set<MetroLine>>{};
    for (final entry in ordersByLine.entries) {
      for (final station in entry.value.keys) {
        linesOf.putIfAbsent(station, () => <MetroLine>{}).add(entry.key);
      }
    }

    String nodeOf(String station, MetroLine line) => '$station|${line.name}';
    String nodeStation(String node) => node.substring(0, node.indexOf('|'));
    String nodeLine(String node) => node.substring(node.indexOf('|') + 1);

    final dist = <String, double>{};
    final hopsTo = <String, int>{};
    final prev = <String, String>{};
    final discovered = <String>{};
    final settled = <String>{};

    void relax(String node, double cost, String from, int hops) {
      final old = dist[node];
      if (old == null || cost < old) {
        dist[node] = cost;
        hopsTo[node] = hops;
        prev[node] = from;
        if (!settled.contains(node)) discovered.add(node);
      }
    }

    for (final line in linesOf[start]!) {
      relax(nodeOf(start, line), 0, nodeOf(start, line), 0);
    }

    String? goal;
    while (discovered.isNotEmpty) {
      var best = discovered.first;
      for (final node in discovered) {
        if (dist[node]! < dist[best]!) best = node;
      }
      discovered.remove(best);
      settled.add(best);

      if (nodeStation(best) == stop) {
        goal = best;
        break;
      }

      final cost = dist[best]!;
      final station = nodeStation(best);
      final line = ordersByLine.keys.firstWhere(
        (l) => l.name == nodeLine(best),
      );
      final order = ordersByLine[line]![station]!;

      final hopCost = switch (gateMode) {
        GateMode.comfortable => 1.0,
        GateMode.fastest => travelMinutesFrom(station),
      };
      for (final nb in _neighbors[station] ?? const <String>[]) {
        final nbOrder = ordersByLine[line]![nb];
        if (nbOrder != null && (nbOrder - order).abs() == 1) {
          relax(nodeOf(nb, line), cost + hopCost, best, hopsTo[best]! + 1);
        }
      }
      for (final other in linesOf[station] ?? const <MetroLine>{}) {
        if (other != line) {
          final transferCost = switch (gateMode) {
            GateMode.comfortable => _transferPenaltyStops,
            GateMode.fastest => transferDwellMinutes + walkMinutesAt(station),
          };
          relax(
            nodeOf(station, other),
            cost + transferCost,
            best,
            hopsTo[best]!,
          );
        }
      }
    }

    if (goal == null) {
      return TripRoute(stations: const [], hops: 0, transfers: 0, minutes: 0);
    }

    final layered = <String>[];
    var current = goal;
    while (true) {
      layered.add(current);
      final back = prev[current]!;
      if (back == current) break;
      current = back;
    }

    final stations = <String>[];
    var lastStation = '';
    for (final node in layered.reversed) {
      final st = nodeStation(node);
      if (st != lastStation) {
        stations.add(_displayNames[st]!);
        lastStation = st;
      }
    }

    var transfers = 0;
    for (var i = 0; i < layered.length - 1; i++) {
      if (nodeLine(layered[i]) != nodeLine(layered[i + 1])) transfers++;
    }

    var minutes = 0.0;
    for (var i = 0; i < layered.length - 1; i++) {
      if (nodeLine(layered[i]) == nodeLine(layered[i + 1])) {
        minutes += travelMinutesFrom(nodeStation(layered[i]));
      } else {
        minutes +=
            transferDwellMinutes + walkMinutesAt(nodeStation(layered[i]));
      }
    }

    return TripRoute(
      stations: stations,
      hops: stations.length - 1,
      transfers: transfers,
      minutes: minutes,
    );
  }

  List<String> directions(List<String> path) {
    if (path.length < 2) return ['None'];

    final result = <String>[];
    var legStart = 0;
    var line = lineOfSegment(path[0], path[1]);

    for (var i = 2; i < path.length; i++) {
      final segmentLine = lineOfSegment(path[i - 1], path[i]);
      if (segmentLine != line) {
        result.add(_legDirection(line!, path, legStart, i - 1));
        line = segmentLine;
        legStart = i - 1;
      }
    }
    result.add(_legDirection(line!, path, legStart, path.length - 1));
    return result;
  }

  String _legDirection(MetroLine line, List<String> path, int start, int end) {
    final orders = <String, int>{};
    for (final s in line.stations) {
      orders[normalize(s.name)] = s.order;
    }
    final firstOrder = orders[normalize(path[start])]!;
    final lastOrder = orders[normalize(path[end])]!;
    return lastOrder > firstOrder
        ? line.stations.last.name
        : line.stations.first.name;
  }
}

class TripRoute {
  const TripRoute({
    required this.stations,
    required this.hops,
    required this.transfers,
    required this.minutes,
  });

  final List<String> stations;
  final int hops;
  final int transfers;
  final double minutes;
}
