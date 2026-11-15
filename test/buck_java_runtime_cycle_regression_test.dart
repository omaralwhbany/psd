import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
import 'package:psd/topologies/buck/buck_inputs.dart';

void main() {
  const engine = BuckEngine();

  test(
    'Buck input-capacitor RMS matches settled PSD5 CCM runtime after stale-iin pass',
    () {
      const input = BuckInputs(
        inputVoltageMin: 18,
        inputVoltageMax: 36,
        outputVoltage: 10,
        outputCurrent: 5,
        switchingFrequency: 200e3,
        rippleFraction: 0.20,
        diodeForwardVoltage: 0.5,
        operatingInputVoltage: 18,
        selectedInductance: 33e-6,
      );

      final result = engine.calculate(input);
      expect(result.isValid, isTrue);
      expect(result.values['isCcm'], 1);
      expect(
        result.values['inputAverageCurrent'],
        closeTo(2.8378378378378377, 1e-15),
      );

      // Direct OpenJDK 21 execution of Buck.calculate() from PSD5.jar:
      // after the output-voltage edit from 12 V to 10 V, the first pass
      // uses the previous iin=3.3783783783783785 A and reports
      // iincap_rms_buck=2.2352655791705716 A. general() then updates iin.
      // The next pass reports 2.4813342227348256 A. Flutter's stateless
      // calculation intentionally returns this settled value immediately.
      expect(
        result.values['inputCapacitorRmsCurrent'],
        closeTo(2.4813342227348256, 1e-12),
      );
    },
  );

  test(
    'Buck input-capacitor RMS matches settled PSD5 DCM runtime after stale-iin pass',
    () {
      const input = BuckInputs(
        inputVoltageMin: 9,
        inputVoltageMax: 16,
        outputVoltage: 4.5,
        outputCurrent: 2,
        switchingFrequency: 100e3,
        rippleFraction: 0.30,
        diodeForwardVoltage: 0.7,
        operatingInputVoltage: 16,
        selectedInductance: 3e-6,
      );

      final result = engine.calculate(input);
      expect(result.isValid, isTrue);
      expect(result.values['isCcm'], 0);
      expect(
        result.values['inputAverageCurrent'],
        closeTo(0.6227544910179641, 1e-15),
      );

      // The original Java first pass after editing 5 V to 4.5 V uses the
      // previous iin=0.6826347305389221 A and reports 1.555763454932851 A.
      // After general() stores the new iin, the second pass reports
      // 1.5750845623591112 A, which is the stable result asserted here.
      expect(
        result.values['inputCapacitorRmsCurrent'],
        closeTo(1.5750845623591112, 1e-12),
      );
    },
  );
}
