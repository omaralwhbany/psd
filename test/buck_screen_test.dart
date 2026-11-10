import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_screen.dart';
import 'package:psd/topologies/buck/buck_schematic.dart';

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
    expect(tester.takeException(), isNull);
  });


  testWidgets('Buck screen displays the Java current-ripple percentage', (tester) async {
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

    // The source runtime case uses the 33 µH selected inductor, not the
    // screen's automatic minimum-inductance mode.
    final customToggle = find.text('Use custom inductor value');
    await tester.ensureVisible(customToggle);
    await tester.tap(customToggle);
    await tester.pumpAndSettle();
    final inductanceField = find.byType(TextField).last;
    await tester.ensureVisible(inductanceField);
    await tester.enterText(inductanceField, '33');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Actual ripple percentage'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Actual ripple percentage'), findsOneWidget);
    expect(find.text('12.29 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  test('Buck freewheel diode cathode faces the switch node', () {
    expect(
      BuckSchematic.diodeCathodeBarY,
      lessThan(BuckSchematic.diodeTriangleApexY),
    );
    expect(
      BuckSchematic.diodeTriangleApexY,
      lessThan(BuckSchematic.diodeAnodeBaseY),
    );
  });


}
