import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
import 'package:psd/topologies/buck/buck_inputs.dart';

void main() {
  test(
    'Buck preserves PSD5 results for an extremely small positive selected inductor',
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
        selectedInductance: 1e-96,
      );

      final result = const BuckEngine().calculate(input);
      expect(result.isValid, isTrue);
      expect(result.values['isCcm'], 0);
      expect(result.values['inductanceUsed'], 1e-96);
      expect(
        result.values['minimumInductance'],
        closeTo(2.7397260273972603e-5, 1e-18),
      );

      // Fixed values from two calculate() calls on the original Buck class
      // in PSD5.jar under OpenJDK 21. The Swing field was set to 1e-90 µH,
      // which Buck.getUserModifiedValues() converts to 1e-96 H.
      expect(
        result.values['designRippleCurrent'],
        closeTo(2.0270270270270274e91, 2.1e77),
      );
      expect(result.values['minimumCurrent'], 0);
      expect(
        result.values['peakCurrent'],
        closeTo(1.4237369936287484e46, 1.5e32),
      );
      expect(
        result.values['rippleCurrent'],
        closeTo(1.4237369936287484e46, 1.5e32),
      );
      expect(
        result.values['ripplePercent'],
        closeTo(2.8474739872574966e47, 2.9e33),
      );

      expect(
        result.values['onTime'],
        closeTo(2.3728949893812472e-51, 2.4e-66),
      );
      expect(
        result.values['offTime'],
        closeTo(1.1389895949029985e-51, 1.2e-66),
      );
      expect(result.values['idleTime'], closeTo(5e-6, 1e-18));
      expect(
        result.values['dutyCycle'],
        closeTo(4.745789978762494e-46, 4.8e-61),
      );

      expect(result.values['outputPower'], 60);
      expect(
        result.values['diodeLosses'],
        closeTo(0.8108108108108105, 1e-14),
      );
      expect(
        result.values['inputPower'],
        closeTo(60.81081081081081, 1e-13),
      );
      expect(
        result.values['inputAverageCurrent'],
        closeTo(3.378378378378378, 1e-14),
      );

      expect(
        result.values['inductorAverageCurrent'],
        closeTo(4.999999999999999, 1e-14),
      );
      expect(
        result.values['inductorRmsCurrent'],
        closeTo(2.1784834125516066e23, 2.2e9),
      );
      expect(
        result.values['mosfetAverageCurrent'],
        closeTo(3.3783783783783776, 1e-14),
      );
      expect(
        result.values['mosfetRmsCurrent'],
        closeTo(1.790702334425015e23, 1.8e9),
      );
      expect(
        result.values['diodeAverageCurrent'],
        closeTo(1.621621621621621, 1e-14),
      );
      expect(
        result.values['diodeRmsCurrent'],
        closeTo(1.2406349697825283e23, 1.3e9),
      );
      expect(
        result.values['inputCapacitorRmsCurrent'],
        closeTo(1.790702334425015e23, 1.8e9),
      );
      expect(
        result.values['outputCapacitorRmsCurrent'],
        closeTo(2.1784834125516066e23, 2.2e9),
      );

      // PSD5 accepts this positive in-range L but flags the requested ripple.
      expect(
        result.warnings,
        contains('Actual inductor ripple exceeds the requested ripple target.'),
      );
    },
  );

  test(
    'Buck preserves PSD5 underflow and NaN results at the smallest positive inductor',
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
        selectedInductance: 5e-324,
      );

      final result = const BuckEngine().calculate(input);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.values['inductanceUsed'], double.minPositive);
      expect(
        result.values['minimumInductance'],
        closeTo(2.7397260273972603e-5, 1e-18),
      );
      expect(result.values['designRippleCurrent'], double.infinity);
      expect(result.values['isCcm'], 0);
      expect(result.values['onTime'], 0);
      expect(result.values['offTime'], 0);
      expect(result.values['idleTime'], closeTo(5e-6, 1e-18));
      expect(result.values['dutyCycle'], 0);
      expect(result.values['minimumCurrent'], 0);

      // Original Buck.java underflows the DCM on/off interval to zero, then
      // evaluates Infinity * 0 in the peak-current expression, producing NaN.
      for (final key in [
        'peakCurrent',
        'rippleCurrent',
        'ripplePercent',
        'inductorAverageCurrent',
        'inductorRmsCurrent',
        'mosfetAverageCurrent',
        'mosfetRmsCurrent',
        'diodeAverageCurrent',
        'diodeRmsCurrent',
        'inputCapacitorRmsCurrent',
        'outputCapacitorRmsCurrent',
        'diodeLosses',
        'inputPower',
        'inputAverageCurrent',
      ]) {
        expect(result.values[key]!.isNaN, isTrue, reason: key);
      }
      expect(result.values['outputPower'], 60);
      expect(
        result.warnings,
        contains('Actual inductor ripple exceeds the requested ripple target.'),
      );
    },
  );

  test(
    'Buck retains PSD5 numeric results for 0% and 101% ripple targets',
    () {
      // These are fixed values read after two calculate() calls on the
      // original Buck class in PSD5.jar under OpenJDK 21. The selected
      // Swing inductance is 10 µH; all other inputs match the fixture below.
      const scenarios = [
        (
          rippleFraction: 0.0,
          error: 'Ripple fraction must be a finite value greater than zero.',
          minimumInductance: double.infinity,
          actualRippleWarning: true,
        ),
        (
          rippleFraction: 1.01,
          error: 'Ripple fraction must not exceed 1 (100%).',
          minimumInductance: 8.137800081378001e-6,
          actualRippleWarning: false,
        ),
      ];

      for (final scenario in scenarios) {
        final result = const BuckEngine().calculate(
          BuckInputs(
            inputVoltageMin: 18,
            inputVoltageMax: 36,
            outputVoltage: 12,
            outputCurrent: 5,
            switchingFrequency: 200e3,
            rippleFraction: scenario.rippleFraction,
            diodeForwardVoltage: 0.5,
            operatingInputVoltage: 18,
            selectedInductance: 10e-6,
          ),
        );

        // PSD5 flags the ripple field but does not discard its calculated
        // values. The selected positive L keeps the 0% case computable too.
        expect(result.isValid, isFalse);
        expect(result.errors, [scenario.error]);
        expect(result.values, isNotEmpty);
        expect(result.values['inductanceUsed'], 10e-6);
        if (scenario.rippleFraction == 0) {
          expect(result.values['minimumInductance'], double.infinity);
        } else {
          expect(
            result.values['minimumInductance'],
            closeTo(8.137800081378001e-6, 1e-18),
          );
        }
        expect(result.values['isCcm'], 1);
        expect(
          result.values['rippleCurrent'],
          closeTo(2.0270270270270263, 1e-14),
        );
        expect(
          result.values['ripplePercent'],
          closeTo(40.540540540540526, 1e-12),
        );
        expect(result.values['inductorAverageCurrent'], 5.0);
        expect(
          result.values['inductorRmsCurrent'],
          closeTo(5.033620540612438, 1e-12),
        );
        expect(
          result.values['mosfetRmsCurrent'],
          closeTo(4.13761059678065, 1e-12),
        );
        expect(
          result.values['diodeRmsCurrent'],
          closeTo(2.866620710223788, 1e-12),
        );
        expect(
          result.values['inputCapacitorRmsCurrent'],
          closeTo(2.389280899087459, 1e-12),
        );
        expect(
          result.values['outputCapacitorRmsCurrent'],
          closeTo(0.5851522998543502, 1e-12),
        );
        expect(result.values['outputPower'], 60.0);
        expect(
          result.values['diodeLosses'],
          closeTo(0.8108108108108105, 1e-14),
        );
        expect(
          result.values['inputPower'],
          closeTo(60.81081081081081, 1e-12),
        );
        expect(
          result.values['inputAverageCurrent'],
          closeTo(3.378378378378378, 1e-14),
        );
        expect(
          result.warnings.contains(
            'Actual inductor ripple exceeds the requested ripple target.',
          ),
          scenario.actualRippleWarning,
        );
      }
    },
  );
}
