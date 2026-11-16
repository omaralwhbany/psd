import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
import 'package:psd/topologies/buck/buck_inputs.dart';

void main() {
  const buck = BuckEngine();

  test('Buck original PSD5 startup point matches the Java runtime oracle', () {
    // Values from Buck.initComponents() and WorkingSheet defaults in the
    // original PSD5_java.zip source and PSD5.jar bytecode.
    const input = BuckInputs(
      inputVoltageMin: 7,
      inputVoltageMax: 30,
      outputVoltage: 3.3,
      outputCurrent: 2,
      switchingFrequency: 1600e3,
      rippleFraction: 0.50,
      diodeForwardVoltage: 0.7,
      operatingInputVoltage: 7,
      selectedInductance: 2.2e-6,
    );

    final result = buck.calculate(input);
    expect(result.isValid, isTrue);
    expect(result.warnings, isEmpty);

    // Fixed values read from the original Buck instance after its constructor
    // performed its two calculate() calls under OpenJDK 21. These expectations
    // are not calculated from BuckEngine.
    expect(
      result.values['minimumInductance'],
      closeTo(2.1742671009771992e-6, 1e-18),
    );
    expect(
      result.values['designRippleCurrent'],
      closeTo(0.5460448642266824, 1e-14),
    );
    expect(result.values['isCcm'], 1);
    expect(result.values['dutyCycle'], closeTo(0.5194805194805194, 1e-14));
    expect(result.values['onTime'], closeTo(3.2467532467532465e-7, 1e-18));
    expect(result.values['offTime'], closeTo(3.003246753246754e-7, 1e-18));
    expect(result.values['idleTime'], closeTo(1e-9, 1e-20));
    expect(result.values['minimumCurrent'], closeTo(1.7269775678866588, 1e-12));
    expect(result.values['peakCurrent'], closeTo(2.273022432113341, 1e-12));
    expect(result.values['inductorAverageCurrent'], closeTo(2.0, 1e-12));
    expect(
      result.values['inductorRmsCurrent'],
      closeTo(2.004599115690954, 1e-12),
    );
    expect(
      result.values['mosfetAverageCurrent'],
      closeTo(1.0389610389610389, 1e-12),
    );
    expect(
      result.values['mosfetRmsCurrent'],
      closeTo(1.4448147528098954, 1e-12),
    );
    expect(
      result.values['diodeAverageCurrent'],
      closeTo(0.9610389610389612, 1e-12),
    );
    expect(
      result.values['diodeRmsCurrent'],
      closeTo(1.3895783334133545, 1e-12),
    );
    expect(
      result.values['inputCapacitorRmsCurrent'],
      closeTo(1.0048751039660124, 1e-12),
    );
    expect(
      result.values['outputCapacitorRmsCurrent'],
      closeTo(0.1576295746754439, 1e-12),
    );
    expect(result.values['outputPower'], closeTo(6.6, 1e-12));
    expect(
      result.values['diodeLosses'],
      closeTo(0.6727272727272728, 1e-12),
    );
    expect(
      result.values['inputPower'],
      closeTo(7.2727272727272725, 1e-12),
    );
    expect(
      result.values['inputAverageCurrent'],
      closeTo(1.0389610389610389, 1e-12),
    );
    expect(
      result.values['ripplePercent'],
      closeTo(27.302243211334122, 1e-10),
    );
  });
}
