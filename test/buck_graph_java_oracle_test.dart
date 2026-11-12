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

  test('Buck graph SI prefixes match Java formatted-label rounding', () {
    BuckDeviceMetrics metrics({
      double minimumVoltage = 0.2,
      double maximumVoltage = 0.3,
      double minimumCurrent = 0.2,
      double maximumCurrent = 0.3,
      double rmsCurrent = 0.4,
      double averageCurrent = 0.3,
      double acCurrent = 0.2,
    }) =>
        BuckDeviceMetrics(
          minimumVoltage: minimumVoltage,
          maximumVoltage: maximumVoltage,
          minimumCurrent: minimumCurrent,
          maximumCurrent: maximumCurrent,
          rmsCurrent: rmsCurrent,
          averageCurrent: averageCurrent,
          acCurrent: acCurrent,
        );

    // Buck.java formats these labels with DecimalFormat("#0.00####"):
    // 0.9999994 -> 0.999999, while 0.9999996 -> 1.00.
    // Graph.java selects mV/mA only when every parsed label remains < 1.
    expect(metrics(minimumVoltage: 0.9999994).voltageScale, 1000);
    expect(metrics(minimumVoltage: 0.9999996).voltageScale, 1);
    expect(metrics(minimumCurrent: -0.9999994).currentScale, 1000);
    expect(metrics(minimumCurrent: -0.9999996).currentScale, 1);
    // OpenJDK DecimalFormat("#0.00####") rounds the exact 0.9999995
    // boundary to 1.00; the immediately lower binary64 value stays below 1.
    expect(metrics(minimumVoltage: 0.9999995).voltageScale, 1);
    expect(metrics(minimumCurrent: -0.9999995).currentScale, 1);
    expect(metrics(minimumVoltage: 0.9999994999999999).voltageScale, 1000);
    // Java formats NaN as "NaN"; Double.parseDouble accepts it, and
    // Graph.java's NaN >= 1 comparison is false, leaving the milli prefix.
    expect(metrics(minimumVoltage: double.nan).voltageScale, 1000);
    expect(metrics(acCurrent: double.nan).currentScale, 1000);
  });

  for (final caseName in ['ccm', 'dcm', 'boundary', 'duty100']) {
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
      // The boundary fixture uses the first representable inductance on
      // Java's CCM side: its ordered calculation returns exactly 10 A.
      expect(result.values['isCcm'], caseName == 'dcm' ? 0 : 1);
      if (caseName == 'boundary') {
        expect(result.values['designRippleCurrent'], 2 * input.outputCurrent);
        expect(result.values['minimumCurrent'], closeTo(0, 1e-12));
      }
      if (caseName == 'duty100') {
        expect(result.values['dutyCycle'], 1);
        expect(result.values['onTime'], closeTo(5e-6, 1e-18));
        expect(result.values['offTime'], 0);
        expect(result.values['idleTime'], 1e-9);
        expect(result.values['mosfetRmsCurrent'],
            closeTo(4.999500074987503, 1e-12));
        expect(result.values['diodeRmsCurrent'], 0);
        expect(result.values['inputCapacitorRmsCurrent'], 0);
        expect(result.values['outputCapacitorRmsCurrent'], 0);
      }

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
        final sourceVoltageSamples = expected['voltage'] as List<dynamic>;
        final sourceCurrentSamples = expected['current'] as List<dynamic>;
        expect(sourceVoltageSamples, hasLength(7));
        expect(sourceCurrentSamples, hasLength(7));
        final expectedVoltage = _expandJavaBuckSamples(sourceVoltageSamples);
        final expectedCurrent = _expandJavaBuckSamples(sourceCurrentSamples);
        expect(device.voltage, hasLength(20));
        expect(device.current, hasLength(20));

        final expectedVoltageMetrics = expected['voltageMetrics'] as List<dynamic>;
        final expectedCurrentMetrics = expected['currentMetrics'] as List<dynamic>;
        expect(expectedVoltageMetrics, hasLength(2));
        expect(expectedCurrentMetrics, hasLength(5));
        expect(
          device.metrics.minimumVoltage,
          closeTo((expectedVoltageMetrics[0] as num).toDouble(), 1e-5),
          reason: '${device.id} Java minimum voltage metric',
        );
        expect(
          device.metrics.maximumVoltage,
          closeTo((expectedVoltageMetrics[1] as num).toDouble(), 1e-5),
          reason: '${device.id} Java maximum voltage metric',
        );
        expect(
          device.metrics.minimumCurrent,
          closeTo((expectedCurrentMetrics[0] as num).toDouble(), 1e-5),
          reason: '${device.id} Java minimum current metric',
        );
        expect(
          device.metrics.maximumCurrent,
          closeTo((expectedCurrentMetrics[1] as num).toDouble(), 1e-5),
          reason: '${device.id} Java maximum current metric',
        );
        expect(
          device.metrics.rmsCurrent,
          closeTo((expectedCurrentMetrics[2] as num).toDouble(), 1e-5),
          reason: '${device.id} Java RMS current metric',
        );
        expect(
          device.metrics.averageCurrent,
          closeTo((expectedCurrentMetrics[3] as num).toDouble(), 1e-5),
          reason: '${device.id} Java average current metric',
        );
        final expectedAcCurrent = expectedCurrentMetrics[4];
        if (expectedAcCurrent == null) {
          expect(
            device.metrics.acCurrent.isNaN,
            isTrue,
            reason: '${device.id} Java AC current metric is NaN',
          );
        } else {
          expect(
            device.metrics.acCurrent,
            closeTo((expectedAcCurrent as num).toDouble(), 1e-5),
            reason: '${device.id} Java AC current metric',
          );
        }
        if (caseName == 'duty100') {
          // The 1 ns source transition offsets overlap when OFF time is zero;
          // Graph.java retains this non-monotonic point order.
          expect(expectedTimes[2], greaterThan(expectedTimes[4]));
        }

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
  test('Buck source-derived device graphs follow the operating load slider', () {
    const input = BuckInputs(
      inputVoltageMin: 18,
      inputVoltageMax: 36,
      outputVoltage: 12,
      outputCurrent: 5,
      switchingFrequency: 200e3,
      rippleFraction: 0.30,
      diodeForwardVoltage: 0.5,
      operatingInputVoltage: 18,
      operatingLoadPercent: 0,
      selectedInductance: 33e-6,
    );
    final result = const BuckEngine().calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['operatingOutputCurrent'], closeTo(0.05, 1e-14));
    expect(result.values['isCcm'], 0);

    final graphs = BuckWaveformSet.fromCalculation(input: input, values: result.values);
    final inductor = graphs.devices.firstWhere((device) => device.id == 'inductor');
    final outputCapacitor = graphs.devices.firstWhere((device) => device.id == 'outputCapacitor');
    expect(inductor.metrics.averageCurrent, closeTo(0.05, 1e-12));
    expect(outputCapacitor.current.first.value, closeTo(-0.05, 1e-12));
    expect(
      outputCapacitor.current[2].value,
      closeTo(result.values['peakCurrent']! - 0.05, 1e-12),
    );
  });

}


/// Expands the seven original Java per-cycle samples into Graph.java's
/// first 20 plotted points; the final 21st source point is intentionally cut.
List<double> _expandJavaBuckSamples(List<dynamic> sourceSamples) {
  final p = sourceSamples.map((value) => (value as num).toDouble()).toList();
  return [
    ...p,
    p[0], p[2], p[3], p[4], p[5], p[6],
    p[0], p[2], p[3], p[4], p[5], p[6],
    p[0], p[2],
  ].take(20).toList();
}
