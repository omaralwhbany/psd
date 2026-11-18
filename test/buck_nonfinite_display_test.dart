import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/core/waveform_chart.dart';
import 'package:psd/localization/app_strings.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
import 'package:psd/topologies/buck/buck_format.dart';
import 'package:psd/topologies/buck/buck_inputs.dart';
import 'package:psd/topologies/buck/buck_screen.dart';
import 'package:psd/topologies/buck/buck_waveforms.dart';

void main() {
  test('TI DecimalFormat special values use the original display strings', () {
    expect(double.infinity.toTiFixed(2), '∞');
    expect(double.negativeInfinity.toTiFixed(2), '-∞');
    expect(double.nan.toTiFixed(2), 'NaN');
    expect(12.345.toTiFixed(2), '12.35');
    expect(double.parse('NaN').isNaN, isTrue);
    expect(() => double.parse('∞'), throwsFormatException);
  });

  test(
    'Buck tiny positive inductance preserves PSD5 non-finite runtime values',
    () {
      const input = BuckInputs(
        inputVoltageMin: 18,
        inputVoltageMax: 36,
        outputVoltage: 12,
        outputCurrent: 5,
        switchingFrequency: 200e3,
        rippleFraction: 0.30,
        diodeForwardVoltage: 0.5,
        operatingInputVoltage: 18,
        selectedInductance: 1e-316,
      );

      final result = const BuckEngine().calculate(input);

      expect(result.isValid, isTrue);
      expect(result.values['isCcm'], 0);
      expect(result.values['peakCurrent'], double.infinity);
      expect(result.values['inductorRmsCurrent'], double.infinity);
      expect(result.values['inputCapacitorRmsCurrent'], isNaN);
      expect(result.values['outputCapacitorRmsCurrent'], isNaN);
      expect(result.values['inputPower'], double.infinity);
    },
  );

  testWidgets(
    'Buck displays TI infinity/NaN values and hides infinite waveforms in both locales',
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

        final customToggle = find.text(AppStrings(locale).customInductor);
        await tester.ensureVisible(customToggle);
        await tester.tap(customToggle);
        await tester.pumpAndSettle();

        final inductanceField = find.byType(TextField).last;
        await tester.ensureVisible(inductanceField);
        await tester.enterText(inductanceField, '1e-310');
        await tester.pumpAndSettle();

        final warning = AppStrings(locale).waveformsUnavailableNonFinite;
        await tester.scrollUntilVisible(
          find.text(warning),
          280,
          scrollable: find.byType(Scrollable).first,
        );

        expect(find.text(warning), findsOneWidget);
        expect(find.text('∞ A'), findsWidgets);
        expect(find.text('NaN A'), findsWidgets);
        expect(find.text('60.00 W'), findsOneWidget);
        expect(find.byType(BuckDeviceWaveformsView), findsNothing);
        expect(find.byType(PowerWaveformChart), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Buck keeps Java-parseable NaN graph labels at the 100% duty boundary',
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

      final outputVoltageField = find.byType(TextField).at(2);
      await tester.ensureVisible(outputVoltageField);
      await tester.enterText(outputVoltageField, '18');
      await tester.pumpAndSettle();

      final customToggle = find.text('Use custom inductor value');
      await tester.ensureVisible(customToggle);
      await tester.tap(customToggle);
      await tester.pumpAndSettle();

      final inductanceField = find.byType(TextField).last;
      await tester.ensureVisible(inductanceField);
      await tester.enterText(inductanceField, '33');
      await tester.pumpAndSettle();

      expect(find.byType(BuckDeviceWaveformsView), findsOneWidget);
      expect(find.byType(PowerWaveformChart), findsOneWidget);
      expect(find.text('NaN'), findsWidgets);
      expect(find.text('Waveform plots are hidden because the plotted values include Infinity.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
