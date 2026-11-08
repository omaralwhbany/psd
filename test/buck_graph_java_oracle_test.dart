import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
import 'package:psd/topologies/buck/buck_inputs.dart';
import 'package:psd/topologies/buck/buck_waveforms.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/buck_graph_java_oracle.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = fixture['cases'] as Map<String, dynamic>;

  for (final caseName in ['ccm', 'dcm']) {
    test('all five Buck $caseName graph traces match original PSD5.jar runtime', () {
      final scenario = cases[caseName] as Map<String, dynamic>;
      final inputValues = scenario['input'] as Map<String, dynamic>;
      double number(String key) => (inputValues[key] as num).toDouble();
      final input = BuckInputs(
        inputVoltageMin: number('inputVoltageMin'),
        inputVoltageMax: number('inputVoltageMax'),
        outputVoltage: number('outputVoltage'),
        outputCurrent: number('outputCurrent'),
        switchingFrequency: number('switchingFrequency'),
        rippleFraction: number('rippleFraction'),
        diodeForwardVoltage: number('diodeForwardVoltage'),
        operatingInputVoltage: number('operatingInputVoltage'),
        selectedInductance: number('selectedInductance'),
      );
      final result = const BuckEngine().calculate(input);
      expect(result.isValid, isTrue);
      expect(result.values['isCcm'], caseName == 'ccm' ? 1 : 0);

      final actual = BuckWaveformSet.fromCalculation(
        input: input,
        values: result.values,
      );
      final expectedGraphs = scenario['graphs'] as Map<String, dynamic>;
      final expectedTimes = (scenario['timeMicroseconds'] as List<dynamic>)
          .map((value) => (value as num).toDouble())
          .toList();

      expect(actual.devices, hasLength(5));
      expect(expectedTimes, hasLength(20));
      expect(
        actual.devices.map((device) => device.id).toSet(),
        expectedGraphs.keys.toSet(),
      );

      for (final device in actual.devices) {
        final expected = expectedGraphs[device.id] as Map<String, dynamic>;
        final expectedVoltage = expected['voltage'] as List<dynamic>;
        final expectedCurrent = expected['current'] as List<dynamic>;
        expect(expectedVoltage, hasLength(20));
        expect(expectedCurrent, hasLength(20));
        expect(device.voltage, hasLength(20));
        expect(device.current, hasLength(20));

        for (var index = 0; index < 20; index++) {
          final time = expectedTimes[index];
          expect(
            device.voltage[index].timeMicroseconds,
            closeTo(time, 1e-9),
            reason: '${device.id} voltage time sample $index',
          );
          expect(
            device.current[index].timeMicroseconds,
            closeTo(time, 1e-9),
            reason: '${device.id} current time sample $index',
          );
          expect(
            device.voltage[index].value,
            closeTo((expectedVoltage[index] as num).toDouble(), 1e-9),
            reason: '${device.id} voltage sample $index',
          );
          expect(
            device.current[index].value,
            closeTo((expectedCurrent[index] as num).toDouble(), 1e-9),
            reason: '${device.id} current sample $index',
          );
        }
      }
    });
  }
}
