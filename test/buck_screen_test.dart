import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_screen.dart';

void main() {
  testWidgets('Buck results fit a narrow Arabic screen without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar'), Locale('en')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: BuckScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('قدرة الخرج'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('قدرة الخرج'), findsOneWidget);
    expect(find.text('قدرة الدخل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Buck screen shows the TI ripple-limit warning without hiding results',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      supportedLocales: [Locale('en'), Locale('ar')],
      home: Scaffold(body: BuckScreen()),
    ));
    await tester.pumpAndSettle();

    final customToggle = find.text('Use custom inductor value');
    await tester.ensureVisible(customToggle);
    await tester.tap(customToggle);
    await tester.pumpAndSettle();
    final inductanceField = find.byType(TextField).last;
    await tester.ensureVisible(inductanceField);
    await tester.enterText(inductanceField, '5');
    await tester.pumpAndSettle();

    expect(find.text('Actual inductor ripple exceeds the requested ripple target.'), findsOneWidget);
    expect(find.text('Operating point'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('Buck ON/OFF time units match PSD5 Java threshold and precision',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      supportedLocales: [Locale('en'), Locale('ar')],
      home: Scaffold(body: BuckScreen()),
    ));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.ensureVisible(fields.at(3));
    await tester.enterText(fields.at(3), '1');
    await tester.ensureVisible(fields.at(5));
    await tester.enterText(fields.at(5), '10000');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('ON time'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('8.11 ns'), findsOneWidget);
    expect(find.text('91.89 ns'), findsOneWidget);
    expect(find.text('0.10 µs'), findsOneWidget);

    await tester.ensureVisible(fields.at(3));
    await tester.enterText(fields.at(3), '18');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('ON time'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    // Java switches at strictly less than 100 ns; exactly 100 ns is 0.10 µs.
    expect(find.text('0.10 µs'), findsNWidgets(2));
    expect(find.text('0.00 ns'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Buck load slider applies the original 1%-to-100% operating range',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      supportedLocales: [Locale('en'), Locale('ar')],
      home: Scaffold(body: BuckScreen()),
    ));
    await tester.pumpAndSettle();

    final loadSlider = find.byType(Slider).first;
    await tester.drag(loadSlider, const Offset(-1000, 0));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Operating load current'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Discontinuous Conduction (DCM)'), findsOneWidget);
    expect(find.text('0.050 A'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('Actual ripple percentage'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('495.68 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


}
