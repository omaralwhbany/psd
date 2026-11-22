import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
import 'package:psd/topologies/buck/buck_inputs.dart';
import 'package:psd/topologies/buck/buck_screen.dart';

void main() {
  const engine = BuckEngine();

  test(
    'Buck retains PSD5 results for finite diode drops outside the allowed range',
    () {
      // Fixed values read after two calculate() calls on the original
      // PSD5.jar Buck class under OpenJDK 21/Xvfb.
      const scenarios = [
        (
          diodeDrop: 5.1,
          designRipple: 2.220779220779221,
          ripplePercent: 44.41558441558442,
          inductorRms: 5.040427281575531,
          mosfetRms: 4.336700387478913,
          diodeRms: 2.568839607700555,
          inputCapacitorRms: 2.2605524875712657,
          outputCapacitorRms: 0.6410837404638052,
          diodeLoss: 6.62337662337663,
          inputPower: 66.62337662337663,
        ),
        (
          diodeDrop: -0.5,
          designRipple: 1.9714285714285715,
          ripplePercent: 39.42857142857143,
          inductorRms: 5.031780379573691,
          mosfetRms: 4.078979974489573,
          diodeRms: 2.9463089036921777,
          inputCapacitorRms: 2.417502433682974,
          outputCapacitorRms: 0.5691024082012026,
          diodeLoss: -0.857142857142854,
          inputPower: 59.142857142857146,
        ),
      ];

      for (final scenario in scenarios) {
        final result = engine.calculate(
          BuckInputs(
            inputVoltageMin: 18,
            inputVoltageMax: 36,
            outputVoltage: 12,
            outputCurrent: 5,
            switchingFrequency: 200e3,
            rippleFraction: 0.30,
            diodeForwardVoltage: scenario.diodeDrop,
            operatingInputVoltage: 18,
            selectedInductance: 10e-6,
          ),
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors,
          ['Diode forward voltage must be between 0 and 5 V.'],
        );
        expect(result.values, isNotEmpty);
        expect(result.values['isCcm'], 1);
        expect(result.values['inductanceUsed'], 10e-6);
        expect(
          result.values['designRippleCurrent'],
          closeTo(scenario.designRipple, 1e-14),
        );
        expect(
          result.values['ripplePercent'],
          closeTo(scenario.ripplePercent, 1e-12),
        );
        expect(
          result.values['inductorRmsCurrent'],
          closeTo(scenario.inductorRms, 1e-12),
        );
        expect(
          result.values['mosfetRmsCurrent'],
          closeTo(scenario.mosfetRms, 1e-12),
        );
        expect(
          result.values['diodeRmsCurrent'],
          closeTo(scenario.diodeRms, 1e-12),
        );
        expect(
          result.values['inputCapacitorRmsCurrent'],
          closeTo(scenario.inputCapacitorRms, 1e-12),
        );
        expect(
          result.values['outputCapacitorRmsCurrent'],
          closeTo(scenario.outputCapacitorRms, 1e-12),
        );
        expect(
          result.values['diodeLosses'],
          closeTo(scenario.diodeLoss, 1e-12),
        );
        expect(result.values['outputPower'], 60);
        expect(
          result.values['inputPower'],
          closeTo(scenario.inputPower, 1e-12),
        );
      }
    },
  );

  test(
    'Buck retains PSD5 results while flagging a positive selected inductor above 2200 µH',
    () {
      final result = const BuckEngine().calculate(
        const BuckInputs(
          inputVoltageMin: 18,
          inputVoltageMax: 36,
          outputVoltage: 12,
          outputCurrent: 5,
          switchingFrequency: 200e3,
          rippleFraction: 0.30,
          diodeForwardVoltage: 0.5,
          operatingInputVoltage: 18,
          selectedInductance: 2200.1e-6,
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        ['Selected inductance must not exceed 2200 µH.'],
      );
      expect(result.values, isNotEmpty);
      expect(result.values['isCcm'], 1);
      expect(result.values['inductanceUsed'], 2200.1e-6);
      expect(
        result.values['minimumInductance'],
        closeTo(27.397260273972603e-6, 1e-18),
      );
      expect(
        result.values['rippleCurrent'],
        closeTo(0.00921334042555877, 1e-14),
      );
      expect(
        result.values['ripplePercent'],
        closeTo(0.18426680851117538, 1e-12),
      );
      expect(
        result.values['inductorRmsCurrent'],
        closeTo(4.999500782297074, 1e-12),
      );
      expect(
        result.values['mosfetRmsCurrent'],
        closeTo(4.109564328209903, 1e-12),
      );
      expect(
        result.values['diodeRmsCurrent'],
        closeTo(2.8471896853728844, 1e-12),
      );
      expect(
        result.values['inputCapacitorRmsCurrent'],
        closeTo(2.3403761945140253, 1e-12),
      );
      expect(
        result.values['outputCapacitorRmsCurrent'],
        closeTo(0.0026596622874160082, 1e-12),
      );
      expect(
        result.values['inputPower'],
        closeTo(60.810810810810814, 1e-12),
      );
      expect(
        result.warnings,
        isNot(contains(
          'Actual inductor ripple exceeds the requested ripple target.',
        )),
      );
    },
  );

  testWidgets(
    'Buck shows post-calculation range errors and keeps their fields highlighted',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BuckScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(7), '5.1');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '2200.1');
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      final theme = Theme.of(tester.element(fields.at(7)));
      expect(
        tester.widget<TextField>(fields.at(7)).decoration!.fillColor,
        theme.colorScheme.error,
      );
      expect(
        tester.widget<TextField>(fields.last).decoration!.fillColor,
        theme.colorScheme.error,
      );
      expect(
        tester.widget<Text>(find.text('33.28 µH')).style!.color,
        theme.colorScheme.error,
      );
      expect(
        find.text('Diode forward voltage must be between 0 and 5 V.'),
        findsOneWidget,
      );
      expect(
        find.text('Selected inductance must not exceed 2200 µH.'),
        findsOneWidget,
      );
      expect(find.text('60.00 W'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Buck retains PSD5 results when negative ripple and an over-limit positive custom inductor coincide',
    () {
      // Expected values were obtained from two calculate() calls on the
      // original PSD5.jar Buck class under OpenJDK 21/Xvfb, with the input
      // slider at 0% and load slider at 100%; independently checked against
      // Buck.java's CCM timing, RMS, and power equations.
      final result = engine.calculate(
        const BuckInputs(
          inputVoltageMin: 18,
          inputVoltageMax: 36,
          outputVoltage: 12,
          outputCurrent: 5,
          switchingFrequency: 200e3,
          rippleFraction: -0.10,
          diodeForwardVoltage: 0.5,
          operatingInputVoltage: 18,
          operatingLoadPercent: 100,
          selectedInductance: 2200.1e-6,
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        containsAll([
          'Selected inductance must not exceed 2200 µH.',
          'Ripple fraction must be a finite value greater than zero.',
        ]),
      );
      expect(result.values, isNotEmpty);
      expect(result.values['isCcm'], 1);
      expect(
        result.values['minimumInductance'],
        closeTo(-82.19178082191781e-6, 1e-18),
      );
      expect(result.values['inductanceUsed'], 2200.1e-6);
      expect(
        result.values['designRippleCurrent'],
        closeTo(0.009213340425558053, 1e-14),
      );
      expect(
        result.values['rippleCurrent'],
        closeTo(0.00921334042555877, 1e-14),
      );
      expect(
        result.values['ripplePercent'],
        closeTo(0.18426680851117538, 1e-12),
      );
      expect(
        result.values['inductorRmsCurrent'],
        closeTo(4.999500782297074, 1e-12),
      );
      expect(
        result.values['mosfetRmsCurrent'],
        closeTo(4.109564328209903, 1e-12),
      );
      expect(
        result.values['diodeRmsCurrent'],
        closeTo(2.8471896853728844, 1e-12),
      );
      expect(
        result.values['inputCapacitorRmsCurrent'],
        closeTo(2.3403761945140253, 1e-12),
      );
      expect(
        result.values['outputCapacitorRmsCurrent'],
        closeTo(0.0026596622874160082, 1e-12),
      );
      expect(
        result.values['diodeLosses'],
        closeTo(0.8108108108108109, 1e-12),
      );
      expect(result.values['outputPower'], 60);
      expect(
        result.values['inputPower'],
        closeTo(60.810810810810814, 1e-12),
      );
      expect(
        result.warnings,
        contains('Actual inductor ripple exceeds the requested ripple target.'),
      );
    },
  );

  testWidgets(
    'Buck keeps results visible for combined invalid ripple and over-limit custom inductance',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BuckScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      final initialFields = find.byType(TextField);
      await tester.enterText(initialFields.at(2), '18');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(6), '-10');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '2200.1');
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      final theme = Theme.of(tester.element(fields.at(6)));
      expect(
        tester.widget<TextField>(fields.at(6)).decoration!.fillColor,
        theme.colorScheme.error,
      );
      expect(
        tester.widget<TextField>(fields.last).decoration!.fillColor,
        theme.colorScheme.error,
      );
      expect(
        find.text('Ripple fraction must be a finite value greater than zero.'),
        findsOneWidget,
      );
      expect(
        find.text('Selected inductance must not exceed 2200 µH.'),
        findsOneWidget,
      );
      expect(find.text('-82.19 µH'), findsOneWidget);
      expect(find.text('0.18 %'), findsOneWidget);
      expect(find.text('60.00 W'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Buck retains PSD5 operating values for non-finite ripple targets with a positive custom inductor',
    () {
      // Each expected result was captured by directly executing Buck from
      // PSD5.jar with OpenJDK 21/Xvfb, after two calculate() calls. The
      // original source and bytecode show calcMinInductance() uses 1/ripple
      // while userCalculate() still uses the independently selected L for
      // operating timing, currents, RMS stresses, and power.
      final scenarios = [
        (
          label: 'NaN ripple',
          rippleFraction: double.nan,
          rippleError:
              'Ripple fraction must be a finite value greater than zero.',
          expectedMinimumIsNaN: true,
          expectedMinimumIsInfinite: false,
          expectedMinimumIsNegative: false,
          expectedRippleWarning: true,
        ),
        (
          label: 'positive infinity ripple',
          rippleFraction: double.infinity,
          rippleError: 'Ripple fraction must not exceed 1 (100%).',
          expectedMinimumIsNaN: false,
          expectedMinimumIsInfinite: false,
          expectedMinimumIsNegative: false,
          expectedRippleWarning: false,
        ),
        (
          label: 'negative infinity ripple',
          rippleFraction: -double.infinity,
          rippleError:
              'Ripple fraction must be a finite value greater than zero.',
          expectedMinimumIsNaN: false,
          expectedMinimumIsInfinite: false,
          expectedMinimumIsNegative: true,
          expectedRippleWarning: true,
        ),
        (
          label: 'negative zero ripple',
          rippleFraction: -0.0,
          rippleError:
              'Ripple fraction must be a finite value greater than zero.',
          expectedMinimumIsNaN: false,
          expectedMinimumIsInfinite: true,
          expectedMinimumIsNegative: true,
          expectedRippleWarning: true,
        ),
      ];

      for (final scenario in scenarios) {
        final result = engine.calculate(
          BuckInputs(
            inputVoltageMin: 18,
            inputVoltageMax: 36,
            outputVoltage: 12,
            outputCurrent: 5,
            switchingFrequency: 200e3,
            rippleFraction: scenario.rippleFraction,
            diodeForwardVoltage: 0.5,
            operatingInputVoltage: 18,
            operatingLoadPercent: 100,
            selectedInductance: 2200.1e-6,
          ),
        );

        expect(result.isValid, isFalse, reason: scenario.label);
        expect(
          result.errors,
          contains('Selected inductance must not exceed 2200 µH.'),
          reason: scenario.label,
        );
        expect(result.errors, contains(scenario.rippleError),
            reason: scenario.label);
        expect(result.values, isNotEmpty, reason: scenario.label);
        expect(result.values['isCcm'], 1, reason: scenario.label);
        expect(
          result.values['inductanceUsed'],
          2200.1e-6,
          reason: scenario.label,
        );

        final minimumInductance = result.values['minimumInductance']!;
        expect(
          minimumInductance.isNaN,
          scenario.expectedMinimumIsNaN,
          reason: scenario.label,
        );
        expect(
          minimumInductance.isInfinite,
          scenario.expectedMinimumIsInfinite,
          reason: scenario.label,
        );
        if (!minimumInductance.isNaN) {
          expect(
            minimumInductance.isNegative,
            scenario.expectedMinimumIsNegative,
            reason: scenario.label,
          );
        }

        expect(
          result.values['onTime'],
          closeTo(3.3783783783783788e-6, 1e-18),
          reason: scenario.label,
        );
        expect(
          result.values['offTime'],
          closeTo(1.6216216216216216e-6, 1e-18),
          reason: scenario.label,
        );
        expect(
          result.values['rippleCurrent'],
          closeTo(0.00921334042555877, 1e-14),
          reason: scenario.label,
        );
        expect(
          result.values['ripplePercent'],
          closeTo(0.18426680851117538, 1e-12),
          reason: scenario.label,
        );
        expect(
          result.values['inductorRmsCurrent'],
          closeTo(4.999500782297074, 1e-12),
          reason: scenario.label,
        );
        expect(
          result.values['mosfetRmsCurrent'],
          closeTo(4.109564328209903, 1e-12),
          reason: scenario.label,
        );
        expect(
          result.values['diodeRmsCurrent'],
          closeTo(2.8471896853728844, 1e-12),
          reason: scenario.label,
        );
        expect(
          result.values['inputCapacitorRmsCurrent'],
          closeTo(2.3403761945140253, 1e-12),
          reason: scenario.label,
        );
        expect(
          result.values['outputCapacitorRmsCurrent'],
          closeTo(0.0026596622874160082, 1e-12),
          reason: scenario.label,
        );
        expect(
          result.values['inputPower'],
          closeTo(60.810810810810814, 1e-12),
          reason: scenario.label,
        );
        expect(
          result.warnings.contains(
            'Actual inductor ripple exceeds the requested ripple target.',
          ),
          scenario.expectedRippleWarning,
          reason: scenario.label,
        );
      }
    },
  );

  test(
    'Buck retains PSD5 results when Vin minimum exceeds maximum',
    () {
      // Values were captured by executing the original PSD5.jar Buck class
      // with the input slider at 0% and 100%, then checked independently
      // against Buck.java's CCM timing, RMS integrals, and power equations.
      const scenarios = [
        (
          vin: 36.0,
          ripple: 4.109589041095891,
          ripplePercent: 82.19178082191782,
          onTime: 1.7123287671232877e-6,
          offTime: 3.2876712328767127e-6,
          inductorRms: 5.138298656618521,
          mosfetRms: 3.006961847034842,
          diodeRms: 4.1665685563884,
          inputCapacitorRms: 2.4719093914436323,
          outputCapacitorRms: 1.1863361695677248,
          inputPower: 61.64383561643836,
        ),
        (
          vin: 18.0,
          ripple: 2.0270270270270263,
          ripplePercent: 40.540540540540526,
          onTime: 3.3783783783783788e-6,
          offTime: 1.6216216216216216e-6,
          inductorRms: 5.033620540612438,
          mosfetRms: 4.13761059678065,
          diodeRms: 2.866620710223788,
          inputCapacitorRms: 2.389280899087459,
          outputCapacitorRms: 0.5851522998543502,
          inputPower: 60.810810810810814,
        ),
      ];

      for (final scenario in scenarios) {
        final result = engine.calculate(
          BuckInputs(
            inputVoltageMin: 36,
            inputVoltageMax: 18,
            outputVoltage: 12,
            outputCurrent: 5,
            switchingFrequency: 200e3,
            rippleFraction: 0.30,
            diodeForwardVoltage: 0.5,
            operatingInputVoltage: scenario.vin,
            operatingLoadPercent: 100,
            selectedInductance: 10e-6,
          ),
        );

        expect(result.isValid, isFalse);
        expect(
          result.errors,
          ['Input voltage minimum cannot exceed maximum.'],
        );
        expect(result.values, isNotEmpty);
        expect(result.values['operatingInputVoltage'], scenario.vin);
        expect(result.values['isCcm'], 1);
        expect(
          result.values['minimumInductance'],
          closeTo(13.513513513513515e-6, 1e-18),
        );
        expect(result.values['inductanceUsed'], 10e-6);
        expect(
          result.values['rippleCurrent'],
          closeTo(scenario.ripple, 1e-12),
        );
        expect(
          result.values['ripplePercent'],
          closeTo(scenario.ripplePercent, 1e-10),
        );
        expect(
          result.values['onTime'],
          closeTo(scenario.onTime, 1e-18),
        );
        expect(
          result.values['offTime'],
          closeTo(scenario.offTime, 1e-18),
        );
        expect(
          result.values['inductorRmsCurrent'],
          closeTo(scenario.inductorRms, 1e-12),
        );
        expect(
          result.values['mosfetRmsCurrent'],
          closeTo(scenario.mosfetRms, 1e-12),
        );
        expect(
          result.values['diodeRmsCurrent'],
          closeTo(scenario.diodeRms, 1e-12),
        );
        expect(
          result.values['inputCapacitorRmsCurrent'],
          closeTo(scenario.inputCapacitorRms, 1e-12),
        );
        expect(
          result.values['outputCapacitorRmsCurrent'],
          closeTo(scenario.outputCapacitorRms, 1e-12),
        );
        expect(result.values['outputPower'], 60);
        expect(
          result.values['inputPower'],
          closeTo(scenario.inputPower, 1e-12),
        );
      }
    },
  );

  testWidgets(
    'Buck highlights both reversed Vin bounds and keeps Java results visible',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BuckScreen())),
      );
      await tester.pumpAndSettle();

      var fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '36');
      await tester.pumpAndSettle();
      fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '18');
      await tester.pumpAndSettle();
      fields = find.byType(TextField);
      await tester.enterText(fields.at(2), '36');
      await tester.pumpAndSettle();

      fields = find.byType(TextField);
      final theme = Theme.of(tester.element(fields.at(0)));
      expect(
        tester.widget<TextField>(fields.at(0)).decoration!.fillColor,
        theme.colorScheme.error,
      );
      expect(
        tester.widget<TextField>(fields.at(1)).decoration!.fillColor,
        theme.colorScheme.error,
      );
      expect(
        tester.widget<TextField>(fields.at(3)).decoration!.fillColor,
        isNot(theme.colorScheme.error),
      );
      expect(
        find.text('Input voltage minimum cannot exceed maximum.'),
        findsOneWidget,
      );
      expect(find.text('13.51 µH'), findsNWidgets(2));
      expect(find.text('60.00 W'), findsOneWidget);
      expect(find.text('61.64 W'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
