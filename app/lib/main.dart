import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/arabic_stations.dart';
import 'data/cairo_university_branch.dart';
import 'data/elmarg_line.dart';
import 'data/elmounib_line.dart';
import 'data/rod_elfarag_line.dart';
import 'models/ticket.dart';
import 'services/metro_graph.dart';
import 'services/nearby_station_locator.dart';
import 'package:geolocator/geolocator.dart';
import 'theme.dart';
import 'utils/normalize.dart';

void main() {
  runApp(const DetroApp());
}

enum AppLang { english, arabic }

String _tr(AppLang lang, String en, String ar) =>
    lang == AppLang.arabic ? ar : en;

String _formatDuration(AppLang lang, double minutes) {
  if (minutes < 60) {
    return '${minutes.toStringAsFixed(0)} '
        '${_tr(lang, 'minute(s)', 'دقيقة')}';
  }
  final h = minutes ~/ 60;
  final m = (minutes % 60).round();
  final hoursLabel = _tr(
    lang,
    h == 1 ? 'hour' : 'hours',
    h == 1 ? 'ساعة' : 'ساعات',
  );
  final minutePart = m == 0 ? '' : ' $m ${_tr(lang, 'minute(s)', 'دقيقة')}';
  return '$h $hoursLabel$minutePart';
}

String _stationName(AppLang lang, String en) =>
    lang == AppLang.arabic ? (arabicStations[en] ?? en) : en;

int _arabicCompare(String a, String b) {
  String fold(String s) => s
      .replaceAll('آ', 'ا')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  return fold(a).compareTo(fold(b));
}

class DetroApp extends StatefulWidget {
  const DetroApp({super.key});

  @override
  State<DetroApp> createState() => _DetroAppState();
}

class _DetroAppState extends State<DetroApp> {
  AppLang _language = AppLang.english;

  void _setLanguage(AppLang language) => setState(() => _language = language);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        title: _tr(_language, 'Detro', 'دترو'),
        debugShowCheckedModeBanner: false,
        locale: Locale(_language == AppLang.arabic ? 'ar' : 'en'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: ThemeMode.system,
        theme: buildAppTheme(
          brightness: Brightness.light,
          dynamicScheme: lightDynamic,
        ),
        darkTheme: buildAppTheme(
          brightness: Brightness.dark,
          dynamicScheme: darkDynamic,
        ),
        home: TripPlannerScreen(
          language: _language,
          onLanguageChanged: _setLanguage,
        ),
      ),
    );
  }
}

class StationOption {
  const StationOption(this.english, this.display);

  final String english;
  final String display;
}

List<StationOption> _fuzzyOptions(String query, List<StationOption> options) {
  final q = normalize(query);
  if (q.isEmpty) return const [];
  final scored = <(int, StationOption)>[];
  for (final o in options) {
    final dEnglish = levenshtein(q, normalize(o.english));
    final dDisplay = levenshtein(q, normalize(o.display));
    scored.add((dEnglish < dDisplay ? dEnglish : dDisplay, o));
  }
  scored.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final e in scored) e.$2].take(6).toList();
}

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppLang language;
  final ValueChanged<AppLang> onLanguageChanged;

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  final MetroGraph graph = MetroGraph(const [
    ElMargLine(),
    ElMounibLine(),
    RodElFaragLine(),
    CairoUniversityBranch(),
  ]);

  final _startController = TextEditingController();
  final _stopController = TextEditingController();
  GateMode _gateMode = GateMode.comfortable;

  TripResult? _result;
  String? _error;
  bool _locating = false;

  @override
  void initState() {
    super.initState();

    _startController.addListener(_onFieldTextChanged);
    _stopController.addListener(_onFieldTextChanged);
  }

  void _onFieldTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _locateStart() async {
    if (_locating) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _locating = true);

    final lang = widget.language;
    LocateResult result;
    try {
      result = await NearbyStationLocator().nearestStation();
    } catch (e) {
      debugPrint('nearestStation threw: $e');
      result = const LocateResult.failed(LocateFailure.unavailable);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
    if (!mounted) return;

    if (result.isSuccess) {
      final detected = result.station!;
      final station = graph.stations.firstWhere(
        (s) => normalize(s) == detected.station,
        orElse: () => detected.station,
      );
      _startController.text = station;
      final km = (detected.distanceMeters / 1000).toStringAsFixed(1);
      _notify(
        _tr(
          lang,
          'Nearest station: $station ($km km away)',
          'أقرب محطة: $station (على بعد $km كم)',
        ),
      );
      return;
    }

    await _handleLocateFailure(result.failure ?? LocateFailure.unavailable);
  }

  void _notify(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  Future<void> _handleLocateFailure(LocateFailure failure) async {
    final lang = widget.language;
    switch (failure) {
      case LocateFailure.serviceDisabled:
        _notify(
          _tr(
            lang,
            'Location is turned off on this device.',
            'خدمة الموقع متوقفة على هذا الجهاز.',
          ),
          action: SnackBarAction(
            label: _tr(lang, 'Settings', 'الإعدادات'),
            onPressed: () => Geolocator.openLocationSettings(),
          ),
        );
      case LocateFailure.permissionDenied:
        _notify(
          _tr(
            lang,
            'Detro needs location permission to find your nearest station.',
            'يحتاج دترو إلى إذن الموقع لإيجاد أقرب محطة إليك.',
          ),
        );
      case LocateFailure.permissionDeniedForever:
        _notify(
          _tr(
            lang,
            'Location permission was permanently denied. Allow it in app settings to use detection.',
            'تم رفض إذن الموقع نهائيًا. اسمح به من إعدادات التطبيق لاستخدام تحديد الموقع.',
          ),
          action: SnackBarAction(
            label: _tr(lang, 'Open', 'فتح'),
            onPressed: () => Geolocator.openAppSettings(),
          ),
        );
      case LocateFailure.noFix:
        _notify(
          _tr(
            lang,
            'Got no location fix. Move somewhere with a clearer view of the sky and try again.',
            'لم يتم تحديد الموقع. انتقل إلى مكان مكشوف وحاول مرة أخرى.',
          ),
        );
      case LocateFailure.unavailable:
        _notify(
          _tr(
            lang,
            'Location is not available on this device.',
            'تحديد الموقع غير متاح على هذا الجهاز.',
          ),
        );
    }
  }

  @override
  void dispose() {
    _startController.removeListener(_onFieldTextChanged);
    _stopController.removeListener(_onFieldTextChanged);
    _startController.dispose();
    _stopController.dispose();
    super.dispose();
  }

  bool get _sameStation {
    final start = _startController.text.trim().toLowerCase();
    final stop = _stopController.text.trim().toLowerCase();
    return start.isNotEmpty && start == stop;
  }

  void _calculate() {
    FocusManager.instance.primaryFocus?.unfocus();
    final start = graph.find(_startController.text);
    final stop = graph.find(_stopController.text);
    if (start == null || stop == null) {
      setState(() {
        _result = null;
        _error = _tr(
          widget.language,
          'Pick both a starting and a stop station.',
          'اختر محطة الانطلاق ومحطة الوصول معًا.',
        );
      });
      return;
    }
    if (_sameStation) {
      setState(() {
        _result = null;
        _error = _tr(
          widget.language,
          'Start and stop stations must be different.',
          'يجب أن تختلف محطة الانطلاق عن محطة الوصول.',
        );
      });
      return;
    }

    final trip = graph.shortestTrip(start, stop, gateMode: _gateMode);
    if (trip.stations.isEmpty) {
      setState(() {
        _result = null;
        _error = _tr(
          widget.language,
          'No route found between those stations.',
          'لا يوجد مسار بين هاتين المحطتين.',
        );
      });
      return;
    }

    final path = trip.stations;
    final rows = <RouteRow>[];
    for (final entry in graph.displayRoute(path)) {
      if (entry == '...') {
        rows.add(RouteRow(name: '...', switchTo: null));
        continue;
      }
      final isChange = entry.endsWith(' (change)');
      final name = isChange ? entry.replaceAll(' (change)', '') : entry;
      String? switchTo;
      if (isChange) {
        final i = path.indexOf(name);
        switchTo = graph.switchLine(path, i);
      }
      rows.add(RouteRow(name: name, switchTo: switchTo));
    }

    setState(() {
      _error = null;
      _result = TripResult(
        route: rows,
        hops: trip.hops,
        transfers: trip.transfers,
        duration: trip.minutes,
        directions: graph.directions(path),
        ticket: TicketType.forHops(trip.hops),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.language;
    final options = [
      for (final s in graph.stations) StationOption(s, _stationName(lang, s)),
    ];
    options.sort(
      lang == AppLang.arabic
          ? (a, b) => _arabicCompare(a.display, b.display)
          : (a, b) =>
                a.english.toLowerCase().compareTo(b.english.toLowerCase()),
    );

    final selStart = normalize(_startController.text);
    final selStop = normalize(_stopController.text);
    final startFieldOptions = [
      for (final o in options)
        if (normalize(o.english) != selStop) o,
    ];
    final stopFieldOptions = [
      for (final o in options)
        if (normalize(o.english) != selStart) o,
    ];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            title: const Text('Detro'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            centerTitle: false,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.center,
              child: SegmentedButton<AppLang>(
                segments: const [
                  ButtonSegment(value: AppLang.english, label: Text('English')),
                  ButtonSegment(value: AppLang.arabic, label: Text('العربية')),
                ],
                selected: {lang},
                onSelectionChanged: (s) => widget.onLanguageChanged(s.first),
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<GateMode>(
              segments: const [
                ButtonSegment(
                  value: GateMode.comfortable,
                  label: Text('Comfortable'),
                  icon: Icon(Icons.airline_seat_recline_normal_outlined),
                ),
                ButtonSegment(
                  value: GateMode.fastest,
                  label: Text('Fastest'),
                  icon: Icon(Icons.bolt_outlined),
                ),
              ],
              selected: {_gateMode},
              onSelectionChanged: (s) => setState(() => _gateMode = s.first),
            ),
            const SizedBox(height: 16),
            _StationField(
              controller: _startController,
              label: _tr(lang, 'Starting station', 'محطة الانطلاق'),
              hintText: _tr(
                lang,
                'Start typing a station name...',
                'ابدأ بكتابة اسم المحطة...',
              ),
              pickerTooltip: _tr(lang, 'Choose from list', 'اختر من القائمة'),
              searchLabel: _tr(lang, 'Search stations', 'ابحث عن المحطات'),
              options: startFieldOptions,
              trailingAction: IconButton(
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                tooltip: _tr(lang, 'Detect nearest station', 'اكشف أقرب محطة'),
                onPressed: _locating ? null : _locateStart,
              ),
            ),
            const SizedBox(height: 12),
            _StationField(
              controller: _stopController,
              label: _tr(lang, 'Stop station', 'محطة الوصول'),
              hintText: _tr(
                lang,
                'Start typing a station name...',
                'ابدأ بكتابة اسم المحطة...',
              ),
              pickerTooltip: _tr(lang, 'Choose from list', 'اختر من القائمة'),
              searchLabel: _tr(lang, 'Search stations', 'ابحث عن المحطات'),
              options: stopFieldOptions,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sameStation ? null : _calculate,
              icon: const Icon(Icons.route),
              label: Text(_tr(lang, 'Calculate trip', 'احسب الرحلة')),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_result != null) _TripSummary(result: _result!, language: lang),
          ],
        ),
      ),
    );
  }
}

class _StationField extends StatefulWidget {
  const _StationField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.pickerTooltip,
    required this.searchLabel,
    required this.options,
    this.trailingAction,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final String pickerTooltip;
  final String searchLabel;
  final List<StationOption> options;
  final Widget? trailingAction;

  @override
  State<_StationField> createState() => _StationFieldState();
}

class _StationFieldState extends State<_StationField> {
  TextEditingController? _autocompleteController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromOuter);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromOuter);
    super.dispose();
  }

  void _syncFromOuter() {
    final target = _autocompleteController;
    if (target == null) return;
    final text = widget.controller.text;
    if (target.text == text) return;
    target.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final label = widget.label;
    final hintText = widget.hintText;
    final pickerTooltip = widget.pickerTooltip;
    final searchLabel = widget.searchLabel;
    final options = widget.options;
    final trailingAction = widget.trailingAction;
    return Autocomplete<StationOption>(
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return const Iterable<StationOption>.empty();
        final query = normalize(value.text);
        final isExact = options.any(
          (o) => normalize(o.english) == query || normalize(o.display) == query,
        );
        if (isExact) return const Iterable<StationOption>.empty();
        final matches = options
            .where(
              (o) =>
                  normalize(o.english).contains(query) ||
                  normalize(o.display).contains(query),
            )
            .toList();
        if (matches.isNotEmpty) return matches;
        return _fuzzyOptions(query, options);
      },
      displayStringForOption: (option) => option.display,
      onSelected: (option) => controller.text = option.english,
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
            _autocompleteController = fieldController;
            return TextField(
              controller: fieldController,
              focusNode: focusNode,
              onChanged: (text) => controller.text = text,
              decoration: InputDecoration(
                labelText: label,
                hintText: hintText,
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?trailingAction,
                    IconButton(
                      icon: const Icon(Icons.list),
                      tooltip: pickerTooltip,
                      onPressed: () async {
                        final picked =
                            await showModalBottomSheet<StationOption>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surface,
                              builder: (context) => _StationPicker(
                                options: options,
                                searchLabel: searchLabel,
                              ),
                            );
                        if (picked != null) {
                          fieldController.text = picked.display;
                          controller.text = picked.english;
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }
}

class _StationPicker extends StatefulWidget {
  const _StationPicker({required this.options, required this.searchLabel});

  final List<StationOption> options;
  final String searchLabel;

  @override
  State<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<_StationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = normalize(_query);
    final isExact =
        _query.isNotEmpty &&
        widget.options.any(
          (o) =>
              normalize(o.english) == normalized ||
              normalize(o.display) == normalized,
        );
    final substring = widget.options
        .where(
          (o) =>
              normalize(o.english).contains(normalized) ||
              normalize(o.display).contains(normalized),
        )
        .toList();
    final filtered = normalized.isEmpty
        ? widget.options
        : isExact
        ? widget.options
        : substring.isNotEmpty
        ? substring
        : _fuzzyOptions(normalized, widget.options);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: widget.searchLabel,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Expanded(
                  child: NotificationListener<ScrollUpdateNotification>(
                    onNotification: (n) {
                      if (n.scrollDelta != 0 &&
                          FocusManager.instance.primaryFocus?.hasFocus ==
                              true) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: const Icon(Icons.subway),
                        title: Text(filtered[i].display),
                        onTap: () => Navigator.pop(context, filtered[i]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.result, required this.language});

  final TripResult result;
  final AppLang language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatBox(
              label: _tr(lang, 'Stations', 'المحطات'),
              value: '${result.hops}',
            ),
            _StatBox(
              label: _tr(lang, 'Transfers', 'التحويلات'),
              value: '${result.transfers}',
            ),
            _StatBox(
              label: _tr(lang, 'Time', 'الوقت'),
              value: _formatDuration(lang, result.duration),
            ),
            _StatBox(
              label: _tr(lang, 'Price', 'السعر'),
              value: _tr(
                lang,
                '${result.ticket.price} EGP (${TicketType.duration} hours)',
                '${result.ticket.price} جنيه (${TicketType.duration} ساعات)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _tr(lang, 'Direction', 'الاتجاه'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in result.directions)
              Chip(
                label: Text(_stationName(lang, d)),
                avatar: const Icon(Icons.directions_subway),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _tr(lang, 'Route', 'المسار'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < result.route.length; i++)
                _RouteTile(index: i, row: result.route[i], language: language),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.index,
    required this.row,
    required this.language,
  });

  final int index;
  final RouteRow row;
  final AppLang language;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
      ),
      title: Text(_stationName(language, row.name)),
      trailing: row.switchTo == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_horiz, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  _tr(
                    language,
                    row.switchTo!,
                    row.switchTo!.replaceFirst('Line ', 'الخط '),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
    );
  }
}

class RouteRow {
  const RouteRow({required this.name, this.switchTo});

  final String name;
  final String? switchTo;
}

class TripResult {
  const TripResult({
    required this.route,
    required this.hops,
    required this.transfers,
    required this.duration,
    required this.directions,
    required this.ticket,
  });

  final List<RouteRow> route;
  final int hops;
  final int transfers;
  final double duration;
  final List<String> directions;
  final TicketType ticket;
}
