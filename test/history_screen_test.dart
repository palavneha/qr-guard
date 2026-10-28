import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madl_project/models/scan_record.dart';
import 'package:madl_project/screens/history_screen.dart';
import 'package:madl_project/services/history_service.dart';
import 'package:madl_project/services/url_analyzer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the empty history state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No scans yet'), findsOneWidget);
    expect(find.text('QR codes you analyze will appear here.'), findsOneWidget);
  });

  testWidgets('lists records newest first and opens stored details', (tester) async {
    final service = HistoryService();
    final olderDate = DateTime(2026, 10, 19, 9);
    final newerDate = DateTime(2026, 10, 20, 11);
    await service.addRecord(
      ScanRecord.fromAnalysis(
        analyzeUrl('https://older.example/path'),
        scannedAt: olderDate,
      ),
    );
    await service.addRecord(
      ScanRecord.fromAnalysis(
        analyzeUrl('https://newer.example/path'),
        scannedAt: newerDate,
      ),
    );

    await tester.pumpWidget(MaterialApp(home: HistoryScreen(historyService: service)));
    await tester.pumpAndSettle();

    expect(find.text('2 scans stored on this device'), findsOneWidget);
    final newerPosition = tester.getTopLeft(find.text('https://newer.example/path')).dy;
    final olderPosition = tester.getTopLeft(find.text('https://older.example/path')).dy;
    expect(newerPosition, lessThan(olderPosition));

    await tester.tap(find.text('https://newer.example/path'));
    await tester.pumpAndSettle();
    expect(find.text('URL risk analysis'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('HTTPS connection'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('HTTPS connection'), findsOneWidget);
  });

  testWidgets('requires confirmation and then clears stored history', (tester) async {
    final service = HistoryService();
    await service.addRecord(
      ScanRecord.fromAnalysis(analyzeUrl('https://clear.example')),
    );
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(historyService: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear scan history'));
    await tester.pumpAndSettle();
    expect(find.text('Clear scan history?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await service.getRecords()).length, 1);

    await tester.tap(find.byTooltip('Clear scan history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();

    expect(await service.getRecords(), isEmpty);
    expect(find.text('No scans yet'), findsOneWidget);
  });
}