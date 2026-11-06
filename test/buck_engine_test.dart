import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
import 'package:psd/topologies/buck/buck_inputs.dart';
import 'package:psd/topologies/boost/boost_engine.dart';
import 'package:psd/topologies/boost/boost_inputs.dart';

void main() {
  const buck = BuckEngine();
  const boost = BoostEngine();

  test('Buck calculates its inductor automatically by default', () {
    final result = buck.calculate(BuckInputs.defaults());
    expect(result.isValid, isTrue);
    expect(result.values['dutyCycle'], greaterThan(0));
    expect(result.values['minimumInductance'], greaterThan(0));
    expect(result.values['inductanceUsed'], result.values['minimumInductance']);
    expect(result.values['peakCurrent'], greaterThan(5));
  });

  test('Buck accepts a custom inductor and reports DCM for a small value', () {
    final input = BuckInputs.defaults();
    final custom = BuckInputs(
      inputVoltageMin: input.inputVoltageMin,
      inputVoltageMax: input.inputVoltageMax,
      outputVoltage: input.outputVoltage,
      outputCurrent: input.outputCurrent,
      switchingFrequency: input.switchingFrequency,
      rippleFraction: input.rippleFraction,
      diodeForwardVoltage: input.diodeForwardVoltage,
      operatingInputVoltage: input.inputVoltageMax,
      selectedInductance: 3e-6,
    );
    final result = buck.calculate(custom);
    expect(result.isValid, isTrue);
    expect(result.values['isCcm'], 0);
    expect(result.values['minimumCurrent'], 0);
    expect(result.values['idleFraction'], greaterThan(0));
    expect(
      result.values['onFraction']! +
          result.values['offFraction']! +
          result.values['idleFraction']!,
      closeTo(1, 1e-9),
    );
  });

  test('Buck default design has no idle interval in CCM', () {
    final result = buck.calculate(BuckInputs.defaults());
    expect(result.isValid, isTrue);
    expect(result.values['isCcm'], 1);
    expect(result.values['idleFraction'], 0);
  });

  test('Boost calculates its inductor automatically by default', () {
    final result = boost.calculate(BoostInputs.defaults());
    expect(result.isValid, isTrue);
    expect(result.values['dutyCycle'], greaterThan(0));
    expect(result.values['minimumInductance'], greaterThan(0));
    expect(result.values['inductanceUsed'], result.values['minimumInductance']);
    expect(result.values['inputAverageCurrent'], greaterThan(0));
  });

  test('Boost custom small inductor reports DCM with three intervals', () {
    const input = BoostInputs(
      inputVoltageMin: 9,
      inputVoltageMax: 16,
      outputVoltage: 24,
      outputCurrent: 2,
      switchingFrequency: 100e3,
      rippleFraction: 0.30,
      operatingInputVoltage: 16,
      selectedInductance: 5e-6,
    );
    final result = boost.calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['isCcm'], 0);
    expect(result.values['minimumCurrent'], 0);
    expect(result.values['idleFraction'], greaterThan(0));
    expect(
      result.values['onFraction']! +
          result.values['offFraction']! +
          result.values['idleFraction']!,
      closeTo(1, 1e-9),
    );
  });

  test('Boost rejects an output voltage that is not above input', () {
    const input = BoostInputs(
      inputVoltageMin: 12,
      inputVoltageMax: 24,
      outputVoltage: 24,
      outputCurrent: 2,
      switchingFrequency: 100e3,
      rippleFraction: 0.3,
    );
    expect(boost.calculate(input).isValid, isFalse);
  });
}