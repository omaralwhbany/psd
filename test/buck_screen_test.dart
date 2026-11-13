import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/localization/app_strings.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
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


  testWidgets(
    'Buck flags minimum-input range in both languages without hiding a valid operating point',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final locale in [const Locale('en'), const Locale('ar')]) {
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: BuckScreen()),
        ));
        await tester.pumpAndSettle();

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '9');
        await tester.enterText(fields.at(1), '18');
        await tester.enterText(fields.at(2), '18');
        await tester.enterText(fields.at(3), '12');
        await tester.pumpAndSettle();

        final expectedWarning = locale.languageCode == 'ar'
            ? 'وفق سلوك PSD5 الأصلي، يتم تمييز جهد الخرج وأقل جهد دخل عندما يتجاوز جهد الخرج أقل جهد دخل.'
            : BuckEngine.outputAboveMinimumInputWarning;
        final operatingPoint = locale.languageCode == 'ar'
            ? 'نقطة التشغيل'
            : 'Operating point';

        expect(find.text(expectedWarning), findsOneWidget);
        expect(find.text(operatingPoint), findsOneWidget);
        expect(find.text('60.00 W'), findsOneWidget);
        expect(tester.widget<TextField>(fields.at(0)).decoration?.filled, isTrue);
        expect(tester.widget<TextField>(fields.at(3)).decoration?.filled, isTrue);
        expect(tester.takeException(), isNull);
      }
    },
  );

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
    // The screen defaults to Lmin = 27.397260273972603 µH, not the 33 µH oracle above.
    expect(find.text('544.01 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets(
    'Buck shows the original low-frequency time warning in English and Arabic',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final locale in [const Locale('en'), const Locale('ar')]) {
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: BuckScreen()),
        ));
        await tester.pumpAndSettle();

        final frequencyField = find.byType(TextField).at(5);
        await tester.ensureVisible(frequencyField);
        await tester.enterText(frequencyField, '0.000001');
        await tester.pumpAndSettle();

        final expectedWarning = locale.languageCode == 'ar'
            ? 'وفق فحص PSD5 الأصلي، يتم تمييز زمن التوصيل وزمن الدورة عندما يكون التردد أقل من زمن التوصيل.'
            : 'PSD5 flags ON time and switching period when switching frequency is below ON time.';
        final operatingPoint = locale.languageCode == 'ar'
            ? 'نقطة التشغيل'
            : 'Operating point';
        expect(find.text(expectedWarning), findsOneWidget);
        expect(find.text(operatingPoint), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  test('Buck zero-automatic-inductance boundary error is localized', () {
    const message =
        'Automatic inductance is zero at the 100% duty boundary; choose a positive custom inductance.';
    expect(AppStrings(const Locale('en')).localizeBuckError(message), message);
    expect(
      AppStrings(const Locale('ar')).localizeBuckError(message),
      'عند حد التشغيل بنسبة 100% تكون المحاثة المحسوبة تلقائياً صفراً؛ اختر محاثة مخصصة موجبة.',
    );
  });

}
