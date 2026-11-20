import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/localization/app_strings.dart';
import 'package:psd/topologies/buck/buck_screen.dart';

void main() {
  testWidgets(
    'Buck tiny-inductor DCM results remain visible on a narrow Arabic screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const locale = Locale('ar');
      await tester.pumpWidget(
        const MaterialApp(
          locale: locale,
          supportedLocales: [Locale('en'), Locale('ar')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: BuckScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final strings = AppStrings(locale);
      expect(
        Directionality.of(tester.element(find.text(strings.buckConverter))),
        TextDirection.rtl,
      );

      final customInductor = find.byType(SwitchListTile);
      await tester.ensureVisible(customInductor);
      await tester.pumpAndSettle();
      await tester.tap(customInductor);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(customInductor).value, isTrue);

      final inductanceField = find.byType(TextField).last;
      await tester.ensureVisible(inductanceField);
      await tester.pumpAndSettle();
      await tester.enterText(inductanceField, '1e-90');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(inductanceField).controller!.text,
        '1e-90',
      );

      // Buck.java showErrors() highlights the requested ripple input when
      // actual inductor ripple exceeds the requested target.
      final rippleField = find.byType(TextField).at(6);
      final rippleInput = tester.widget<TextField>(rippleField);
      final rippleTheme = Theme.of(tester.element(rippleField));
      expect(rippleInput.decoration!.filled, isTrue);
      expect(rippleInput.decoration!.fillColor, rippleTheme.colorScheme.error);
      expect(rippleInput.style!.color, rippleTheme.colorScheme.onError);

      final rippleWarning = find.text(
        strings.localizeBuckWarning(
          'Actual inductor ripple exceeds the requested ripple target.',
        ),
      );
      await tester.ensureVisible(rippleWarning);
      await tester.pumpAndSettle();

      expect(find.text(strings.outputPower), findsOneWidget);
      expect(find.text(strings.inputPower), findsOneWidget);
      expect(rippleWarning, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Buck highlights invalid ripple targets like PSD5',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BuckScreen())),
      );
      await tester.pumpAndSettle();

      final rippleField = find.byType(TextField).at(6);
      final theme = Theme.of(tester.element(rippleField));
      for (final value in ['0', '101']) {
        await tester.enterText(rippleField, value);
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(rippleField);
        expect(field.decoration!.filled, isTrue, reason: value);
        expect(
          field.decoration!.fillColor,
          theme.colorScheme.error,
          reason: value,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Buck renders the smallest-positive inductor PSD5 edge case on a narrow Arabic screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const locale = Locale('ar');
      await tester.pumpWidget(
        const MaterialApp(
          locale: locale,
          supportedLocales: [Locale('en'), Locale('ar')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: BuckScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final customInductor = find.byType(SwitchListTile);
      await tester.ensureVisible(customInductor);
      await tester.pumpAndSettle();
      await tester.tap(customInductor);
      await tester.pumpAndSettle();

      final inductanceField = find.byType(TextField).last;
      await tester.ensureVisible(inductanceField);
      await tester.pumpAndSettle();
      await tester.enterText(inductanceField, '5e-318');
      await tester.pumpAndSettle();

      final rippleField = find.byType(TextField).at(6);
      final rippleTheme = Theme.of(tester.element(rippleField));
      final rippleInput = tester.widget<TextField>(rippleField);
      expect(rippleInput.decoration!.filled, isTrue);
      expect(rippleInput.decoration!.fillColor, rippleTheme.colorScheme.error);

      final outputPower = find.text(AppStrings(locale).outputPower);
      await tester.ensureVisible(outputPower);
      await tester.pumpAndSettle();
      expect(outputPower, findsOneWidget);

      final deviceWaveforms = find.text(AppStrings(locale).deviceWaveforms);
      await tester.ensureVisible(deviceWaveforms);
      await tester.pumpAndSettle();
      expect(deviceWaveforms, findsOneWidget);

      final synchronizedWaveforms =
          find.text(AppStrings(locale).synchronizedWaveforms);
      final scrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        synchronizedWaveforms,
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(synchronizedWaveforms, findsOneWidget);
      expect(
        find.text(AppStrings(locale).waveformUnavailableForNonFiniteResults),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Buck highlights actual ripple percentage when measured ripple exceeds target',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const locale = Locale('en');
      await tester.pumpWidget(
        const MaterialApp(
          locale: locale,
          supportedLocales: [Locale('en'), Locale('ar')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: BuckScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final customInductor = find.byType(SwitchListTile);
      await tester.scrollUntilVisible(
        customInductor,
        280,
        scrollable: scrollable,
      );
      await tester.tap(customInductor);
      await tester.pumpAndSettle();

      final inductanceField = find.byType(TextField).last;
      await tester.scrollUntilVisible(
        inductanceField,
        280,
        scrollable: scrollable,
      );
      await tester.enterText(inductanceField, '10');
      await tester.pumpAndSettle();

      // Original Buck from PSD5.jar (OpenJDK 21), with
      // Vin(min/max)=18/36 V, Vo=12 V, Iout=5 A, fs=200 kHz,
      // Vf=0.5 V, ripple target=30%, L=10 µH, Vin slider=0%:
      // jLabelCurrentRipplePercent displays 40.54 and is red.
      final strings = AppStrings(locale);
      final actualRippleLabel = find.text(strings.actualRipplePercent);
      final actualRippleValue = find.text('40.54 %');
      await tester.scrollUntilVisible(
        actualRippleValue,
        280,
        scrollable: scrollable,
      );

      expect(actualRippleLabel, findsOneWidget);
      expect(actualRippleValue, findsOneWidget);
      final theme = Theme.of(tester.element(actualRippleValue));
      expect(
        tester.widget<Text>(actualRippleValue).style?.color,
        theme.colorScheme.error,
      );

      final rippleField = find.byType(TextField).at(6);
      expect(
        tester.widget<TextField>(rippleField).decoration!.fillColor,
        theme.colorScheme.error,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
