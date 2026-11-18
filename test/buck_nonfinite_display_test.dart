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
    expect(double.infinity.toTiDisplayStringAsFixed(2), '∞');
    expect(double.negativeInfinity.toTiDisplayStringAsFixed(2), '-∞');
    expect(double.nan.toTiDisplayStringAsFixed(2), 'NaN');
    expect(12.345.toTiDisplayStringAsFixed(2), '12.35');
  });

  test('Buck tiny positive inductance preserves PSD5 non-finite runtime values', () {
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
  });

  testWidgets(
    'Buck displays TI infinity/NaN values and hides non-finite waveforms in both locales',
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
}
