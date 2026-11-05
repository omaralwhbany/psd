import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
import 'package:psd/topologies/buck/buck_inputs.dart';

void main() {
  const engine = BuckEngine();
  test('calculates a valid Buck operating point', () {
    final result = engine.calculate(BuckInputs.defaults());
    expect(result.isValid, isTrue);
    expect(result.values['dutyCycle'], greaterThan(0));
    expect(result.values['minimumInductance'], greaterThan(0));
    expect(result.values['peakCurrent'], greaterThan(5));
  });
  test('rejects output voltage above minimum input voltage', () {
    const input = BuckInputs(inputVoltageMin: 10, inputVoltageMax: 24, outputVoltage: 12, outputCurrent: 2, switchingFrequency: 100e3, rippleFraction: 0.3, diodeForwardVoltage: 0.5, inductance: 100e-6);
    expect(engine.calculate(input).isValid, isFalse);
  });
  test('reports DCM when selected inductance produces negative valley current', () {
    const input = BuckInputs(inputVoltageMin: 18, inputVoltageMax: 36, outputVoltage: 12, outputCurrent: 5, switchingFrequency: 200e3, rippleFraction: 0.3, diodeForwardVoltage: 0.5, inductance: 5e-6);
    expect(engine.calculate(input).values['isCcm'], 0);
  });
}
