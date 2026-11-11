import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
import 'package:psd/topologies/buck/buck_inputs.dart';

void main() {
  const buck = BuckEngine();

  test(
    'Buck ripple follows PSD5 general peak-minus-valley subtraction order',
    () {
      const input = BuckInputs(
        inputVoltageMin: 809.4736305932962,
        inputVoltageMax: 809.4736305932962,
        outputVoltage: 330.114238451388,
        outputCurrent: 92.48939803523659,
        switchingFrequency: 831605.2019290418,
        rippleFraction: 0.30,
        diodeForwardVoltage: 1.7138706798677177,
        operatingInputVoltage: 809.4736305932962,
        selectedInductance: 2.9741331803770024e-4,
      );

      final result = buck.calculate(input);
      expect(result.isValid, isTrue);
      expect(result.values['isCcm'], 1);

      // Actual two-pass execution of Buck.calculate() from PSD5.jar/OpenJDK 21.
      // general() reports iind_max - iind_min, not iripple_buck.
      expect(
        result.values['designRippleCurrent'],
        closeTo(0.7928217453261514, 1e-15),
      );
      expect(
        result.values['rippleCurrent'],
        closeTo(0.7928217453261652, 1e-15),
      );
      expect(
        result.values['ripplePercent'],
        closeTo(0.8572028385611463, 1e-15),
      );
    },
  );

  test('Buck preserves raw tiny negative DCM idle time from PSD5.jar', () {
    const input = BuckInputs(
      inputVoltageMin: 318.08966531879963,
      inputVoltageMax: 318.08966531879963,
      outputVoltage: 98.24616678566447,
      outputCurrent: 651.0248847976459,
      switchingFrequency: 2524.911090771719,
      rippleFraction: 0.30,
      diodeForwardVoltage: 1.7531008550235228,
      operatingInputVoltage: 318.08966531879963,
      selectedInductance: 2.090741011014667e-5,
    );

    final result = buck.calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['isCcm'], 0);

    // The original onofftimes() stores 1/fs - ton - toff without clamping.
    // This value came from two actual calculate() calls on the original JAR.
    expect(
      result.values['idleTime'],
      closeTo(-1.0842021724855044e-19, 1e-30),
    );
    expect(result.values['idleTime'], lessThan(0));
    expect(
      result.values['inputCapacitorRmsCurrent'],
      closeTo(367.7671721738053, 1e-9),
    );
    expect(
      result.values['outputCapacitorRmsCurrent'],
      closeTo(375.86939248706585, 1e-9),
    );
  });
}
