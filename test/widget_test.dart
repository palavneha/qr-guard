import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madl_project/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('home screen fits a compact phone viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const QRGuardApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.text('No scans yet'), findsOneWidget);
  });

  testWidgets('home navigation opens the scan history screen', (tester) async {
    await tester.pumpWidget(const QRGuardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan History'));
    await tester.pumpAndSettle();

    expect(find.text('Scan History'), findsOneWidget);
    expect(find.text('No scans yet'), findsOneWidget);
  });

  testWidgets('home navigation opens the QR generator screen', (tester) async {
    await tester.pumpWidget(const QRGuardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Generate QR Code'), findsOneWidget);
    expect(find.text('Live QR Code Preview'), findsOneWidget);
  });
}
