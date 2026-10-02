import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:detro/data/cairo_university_branch.dart';
import 'package:detro/data/elmarg_line.dart';
import 'package:detro/data/elmounib_line.dart';
import 'package:detro/data/rod_elfarag_line.dart';
import 'package:detro/main.dart';
import 'package:detro/services/metro_graph.dart';
import 'package:detro/utils/normalize.dart';

void main() {
  testWidgets('App renders the trip planner screen', (tester) async {
    await tester.pumpWidget(const DetroApp());

    expect(find.text('Detro'), findsOneWidget);
    expect(find.text('Starting station'), findsOneWidget);
    expect(find.text('Stop station'), findsOneWidget);
    expect(find.text('Calculate trip'), findsOneWidget);
  });

  testWidgets('Station picker opens from the list button', (tester) async {
    await tester.pumpWidget(const DetroApp());

    expect(find.byIcon(Icons.list), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.list).first);
    await tester.pumpAndSettle();

    expect(find.text('Search stations'), findsOneWidget);
    expect(find.text('Adly Mansour'), findsOneWidget);

    await tester.tap(find.text('Adly Mansour'));
    await tester.pumpAndSettle();
    expect(find.text('Adly Mansour'), findsOneWidget);
  });

  testWidgets('Arabic toggle translates UI and station picker', (tester) async {
    await tester.pumpWidget(const DetroApp());

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text('Detro'), findsOneWidget);
    expect(find.text('احسب الرحلة'), findsOneWidget);
    expect(find.text('محطة الانطلاق'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.list).first);
    await tester.pumpAndSettle();
    expect(find.text('أرض المعارض'), findsOneWidget);
  });

  testWidgets('Fuzzy search catches a typo in the station field',
      (tester) async {
    await tester.pumpWidget(const DetroApp());

    await tester.enterText(find.byType(TextField).first, 'adly mansor');
    await tester.pumpAndSettle();

    expect(find.text('Adly Mansour'), findsWidgets);
  });

  test('Fuzzy rank orders closest station matches first', () {
    final ranked = fuzzyRank('adly mansor', const [
      'Adly Mansour',
      'Adly',
      'Mansour',
      'Dokki',
    ]);

    expect(ranked.first, 'Adly Mansour');
  });

  test('Graph routes across lines', () {
    final graph = MetroGraph(const [
      ElMargLine(),
      ElMounibLine(),
      RodElFaragLine(),
      CairoUniversityBranch(),
    ]);

    final path = graph.shortestPath('elmarg', 'dokki');
    expect(path.length, 18);
    expect(path.first, 'El-Marg');
    expect(path.last, 'Dokki');
  });
}
