import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

  testWidgets(
    'Buck graph metric labels preserve Java two-stage DecimalFormat rounding',
    (tester) async {
      const value = 0.47791537253375116;
      const metrics = BuckDeviceMetrics(
        minimumVoltage: value,
        maximumVoltage: value,
        minimumCurrent: value,
        maximumCurrent: value,
        rmsCurrent: value,
        averageCurrent: value,
        acCurrent: value,
      );
      const waveforms = BuckWaveformSet([
        BuckDeviceWaveform(
          id: 'inductor',
          title: 'Inductor L1',
          voltage: [
            BuckWaveformPoint(0, value),
            BuckWaveformPoint(1, value),
          ],
          current: [
            BuckWaveformPoint(0, value),
            BuckWaveformPoint(1, value),
          ],
          metrics: metrics,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BuckDeviceWaveformsView(
                waveforms: waveforms,
                voltageLabel: 'Voltage',
                currentLabel: 'Current',
                periodLabel: 'One switching period',
                timeAxisLabel: 'Time (µs)',
                deviceTitles: const {'inductor': 'Inductor L1'},
                metricLabels: const {
                  'minimumVoltage': 'Vmin',
                  'maximumVoltage': 'Vmax',
                  'minimumCurrent': 'Imin',
                  'maximumCurrent': 'Imax',
                  'rmsCurrent': 'Irms',
                  'averageCurrent': 'Iavg',
                  'acCurrent': 'Iac',
                },
              ),
            ),
          ),
        ),
      );

      // Buck.java rounds to six fractional digits before Graph.java parses,
      // scales to mV/mA, and formats again to two fractional digits.
      expect(find.text('Vmin: 477.91 mV'), findsOneWidget);
      expect(find.text('Imin: 477.91 mA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final caseName in ['ccm', 'dcm', 'boundary', 'duty100']) {
    test('all five Buck $caseName graph traces match original PSD5.jar runtime',
        () {
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

        final expectedVoltageMetrics =
            expected['voltageMetrics'] as List<dynamic>;
        final expectedCurrentMetrics =
            expected['currentMetrics'] as List<dynamic>;
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
          expect(expectedTimes[5], greaterThan(expectedTimes[6]));
        }

        for (var index = 0; index < 20; index++) {
          final time = expectedTimes[index];
          expect(
            device.voltage[index].timeMicroseconds,
            time,
            reason: '${device.id} voltage time sample $index',
          );
          expect(
            device.current[index].timeMicroseconds,
            time,
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
  test('Buck GraphPanel maps non-finite X bounds like Java', () {
    const left = 65.0;
    const width = 70.0;

    // OpenJDK 21 GraphPanel runtime at 200x150 uses X=70 and x origin 65.
    // For equal x bounds it selects mappingX=100 rather than dividing by 0.
    const zeroRange = BuckGraphTimeRange(
      minimumMicroseconds: 1,
      maximumMicroseconds: 1,
    );
    expect(zeroRange.graphPanelXOffset(1, width), 100);
    expect(left + zeroRange.graphPanelXOffset(1, width), 165);
    expect(
      zeroRange.graphPanelTickLabelValue(1, width),
      closeTo(100 / 70, 1e-12),
    );
    expect(
      buckJavaGraphPanelFallbackX(
        value: 1,
        minimum: 1,
        maximum: 1,
        plotLeft: left,
        plotWidth: width,
      ),
      isNull,
    );

    // Direct GraphPanel runtime probes: a first NaN pins both extrema and
    // maps every x coordinate to int zero; a later NaN is ignored by extrema
    // scanning but its own plotted coordinate still narrows to zero.
    expect(
      buckJavaGraphPanelFallbackX(
        value: 1,
        minimum: double.nan,
        maximum: double.nan,
        plotLeft: left,
        plotWidth: width,
      ),
      0,
    );
    expect(
      buckJavaGraphPanelFallbackX(
        value: double.nan,
        minimum: 0,
        maximum: 2,
        plotLeft: left,
        plotWidth: width,
      ),
      0,
    );

    // With an infinite range (including finite subtraction overflow), the
    // Java mapping factor is zero: finite samples remain at the x origin,
    // while Infinity*0 becomes NaN and narrows to integer zero.
    expect(
      buckJavaGraphPanelFallbackX(
        value: 1,
        minimum: 0,
        maximum: double.infinity,
        plotLeft: left,
        plotWidth: width,
      ),
      left,
    );
    expect(
      buckJavaGraphPanelFallbackX(
        value: double.infinity,
        minimum: 0,
        maximum: double.infinity,
        plotLeft: left,
        plotWidth: width,
      ),
      0,
    );
    expect(
      buckJavaGraphPanelFallbackX(
        value: 1e308,
        minimum: -1e308,
        maximum: 1e308,
        plotLeft: left,
        plotWidth: width,
      ),
      left,
    );

    // A subnormal x span overflows mappingX; JVM d2i saturates to int limits.
    expect(
      buckJavaGraphPanelFallbackX(
        value: -double.minPositive,
        minimum: -double.minPositive,
        maximum: double.minPositive,
        plotLeft: left,
        plotWidth: width,
      ),
      -2147483648.0,
    );
    expect(
      buckJavaGraphPanelFallbackX(
        value: double.minPositive,
        minimum: -double.minPositive,
        maximum: double.minPositive,
        plotLeft: left,
        plotWidth: width,
      ),
      2147483647.0,
    );
  });

  test('Buck GraphPanel axis labels match Java DecimalFormat', () {
    // GraphPanel.paintComponent uses DecimalFormat("#0.00") for every axis
    // and tick label. These values are pinned by OpenJDK 21 runtime probes.
    expect(buckJavaGraphPanelAxisLabel(1.125), '1.12');
    expect(buckJavaGraphPanelAxisLabel(1.375), '1.38');
    expect(buckJavaGraphPanelAxisLabel(-1.125), '-1.12');
    expect(buckJavaGraphPanelAxisLabel(-1.375), '-1.38');
    expect(buckJavaGraphPanelAxisLabel(0.005), '0.01');
    expect(buckJavaGraphPanelAxisLabel(1.25), '1.25');
    expect(buckJavaGraphPanelAxisLabel(double.nan), 'NaN');
    expect(buckJavaGraphPanelAxisLabel(double.infinity), '∞');
    expect(buckJavaGraphPanelAxisLabel(double.negativeInfinity), '-∞');
  });

  test('Buck GraphPanel maps non-finite Y bounds like Java', () {
    const top = 7.0;
    const bottom = 75.0;

    // Original PSD5.jar GraphPanel runtime with [1, 2, +Infinity, 3]:
    // finite points stay on the zero baseline; the infinite point narrows
    // through NaN to Java int zero.
    expect(
      buckJavaGraphPanelFallbackY(
        value: 1,
        minimum: 0,
        maximum: double.infinity,
        plotTop: top,
        plotBottom: bottom,
      ),
      bottom,
    );
    expect(
      buckJavaGraphPanelFallbackY(
        value: double.infinity,
        minimum: 0,
        maximum: double.infinity,
        plotTop: top,
        plotBottom: bottom,
      ),
      0,
    );
    expect(
      buckJavaGraphPanelFallbackY(
        value: 3,
        minimum: double.negativeInfinity,
        maximum: 3,
        plotTop: top,
        plotBottom: bottom,
      ),
      0,
    );
    expect(
      buckJavaGraphPanelFallbackY(
        value: double.nan,
        minimum: double.nan,
        maximum: double.nan,
        plotTop: top,
        plotBottom: bottom,
      ),
      0,
    );

    // GraphPanel ignores a NaN that appears after finite samples while
    // scanning extrema, but its plotted coordinate still narrows NaN to 0.
    expect(
      buckJavaGraphPanelFallbackY(
        value: double.nan,
        minimum: 0,
        maximum: 3,
        plotTop: top,
        plotBottom: bottom,
      ),
      0,
    );

    // With a negative-infinity minimum, GraphPanel clamps the maximum to
    // zero and keeps finite samples on the upper baseline.
    expect(
      buckJavaGraphPanelFallbackY(
        value: -1,
        minimum: double.negativeInfinity,
        maximum: 0,
        plotTop: top,
        plotBottom: bottom,
      ),
      top,
    );

    // A finite range whose subtraction overflows also gives Java a zero
    // mapping factor, leaving finite samples at the source baseline.
    expect(
      buckJavaGraphPanelFallbackY(
        value: 1e308,
        minimum: -1e308,
        maximum: 1e308,
        plotTop: top,
        plotBottom: bottom,
      ),
      bottom,
    );
    // A subnormal finite span overflows mappingY. The JVM d2i conversion
    // saturates the resulting positive and negative infinities to int bounds.
    expect(
      buckJavaGraphPanelFallbackY(
        value: -double.minPositive,
        minimum: -double.minPositive,
        maximum: double.minPositive,
        plotTop: top,
        plotBottom: bottom,
      ),
      2147483647.0,
    );
    expect(
      buckJavaGraphPanelFallbackY(
        value: double.minPositive,
        minimum: -double.minPositive,
        maximum: double.minPositive,
        plotTop: top,
        plotBottom: bottom,
      ),
      -2147483648.0,
    );

    expect(
      buckJavaGraphPanelFallbackY(
        value: 2,
        minimum: 0,
        maximum: 4,
        plotTop: top,
        plotBottom: bottom,
      ),
      isNull,
    );
  });

  test('Buck source-derived device graphs follow the operating load slider',
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
      operatingLoadPercent: 0,
      selectedInductance: 33e-6,
    );
    final result = const BuckEngine().calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['operatingOutputCurrent'], closeTo(0.05, 1e-14));
    expect(result.values['isCcm'], 0);

    final graphs =
        BuckWaveformSet.fromCalculation(input: input, values: result.values);
    final inductor =
        graphs.devices.firstWhere((device) => device.id == 'inductor');
    final outputCapacitor =
        graphs.devices.firstWhere((device) => device.id == 'outputCapacitor');
    expect(inductor.metrics.averageCurrent, closeTo(0.05, 1e-12));
    expect(outputCapacitor.current.first.value, closeTo(-0.05, 1e-12));
    expect(
      outputCapacitor.current[2].value,
      closeTo(result.values['peakCurrent']! - 0.05, 1e-12),
    );
  });

  test('Buck graph time range includes sub-nanosecond transition samples', () {
    const input = BuckInputs(
      inputVoltageMin: 10000,
      inputVoltageMax: 10000,
      outputVoltage: 0.001,
      outputCurrent: 5,
      switchingFrequency: 10e6,
      rippleFraction: 0.30,
      diodeForwardVoltage: 0.5,
      operatingInputVoltage: 10000,
      selectedInductance: 2200e-6,
    );
    final result = const BuckEngine().calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['isCcm'], 1);

    final waveforms = BuckWaveformSet.fromCalculation(
      input: input,
      values: result.values,
    );
    final inductor = waveforms.devices.firstWhere(
      (device) => device.id == 'inductor',
    );
    final points = inductor.voltage;
    expect(points, hasLength(20));
    // Original PSD5.jar runtime: ton=5.009749512524374 ps, so the
    // source's ton - 1 ns transition is a negative x-coordinate.
    expect(
      points[2].timeMicroseconds,
      closeTo(-0.0009949902504874757, 1e-15),
    );

    final range = BuckGraphTimeRange.fromPoints(points);
    // GraphPanel.getMinimumX() scans all 20 retained Graph.java points;
    // it does not assume the first point is the minimum.
    expect(
      range.minimumMicroseconds,
      closeTo(-0.0009949902504874757, 1e-15),
    );
    expect(
      range.maximumMicroseconds,
      closeTo(0.30400000000000005, 1e-12),
    );
    expect(
        points.first.timeMicroseconds, greaterThan(range.minimumMicroseconds));

    // Original GraphPanel uses mappingX = X / abs(maxX - minX), then
    // screenX = 65 + time * mappingX. It does not translate by minX.
    // This runtime probe used a 600 px panel, so X = width - 130 = 470.
    const graphPanelWidth = 470.0;
    expect(
      range.graphPanelXOffset(points[0].timeMicroseconds, graphPanelWidth),
      0,
    );
    expect(
      range.graphPanelXOffset(points[2].timeMicroseconds, graphPanelWidth),
      closeTo(-1.53328884958092, 1e-12),
    );
    expect(
      range.graphPanelXOffset(points[19].timeMicroseconds, graphPanelWidth),
      closeTo(468.4667111504191, 1e-12),
    );
    // GraphPanel labels each tick as maxX * (time * mappingX / X).
    expect(
      range.graphPanelTickLabelValue(
        points[6].timeMicroseconds,
        graphPanelWidth,
      ),
      closeTo(0.09967376832987639, 1e-15),
    );
    expect(
      range.graphPanelTickLabelValue(
        points[18].timeMicroseconds,
        graphPanelWidth,
      ),
      closeTo(0.3010147803562267, 1e-15),
    );
  });

  test('Buck original TI default operating point matches PSD5.jar runtime', () {
    const input = BuckInputs(
      inputVoltageMin: 7,
      inputVoltageMax: 30,
      outputVoltage: 3.3,
      outputCurrent: 2,
      switchingFrequency: 1.6e6,
      rippleFraction: 0.5,
      diodeForwardVoltage: 0.7,
      operatingInputVoltage: 7,
      operatingLoadPercent: 100,
      selectedInductance: 2.2e-6,
    );

    final result = const BuckEngine().calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['isCcm'], 1);

    // These fixed values came from two constructor-time calculate() passes
    // on the original PSD5.jar Buck class under OpenJDK 21. The Java sheet
    // defaults to Vin=7..30 V, Vo=3.3 V, Iout=2 A, fs=1.6 MHz,
    // 50% ripple, Vf=0.7 V, and a selected 2.2 uH inductor.
    expect(
      result.values['minimumInductance'],
      closeTo(2.1742671009771992e-6, 1e-18),
    );
    expect(result.values['inductanceUsed'], 2.2e-6);
    expect(
      result.values['designRippleCurrent'],
      closeTo(0.5460448642266824, 1e-14),
    );
    expect(
      result.values['rippleCurrent'],
      closeTo(0.5460448642266824, 1e-14),
    );
    expect(
      result.values['dutyCycle'],
      closeTo(0.5194805194805194, 1e-15),
    );
    expect(result.values['onTime'], closeTo(3.2467532467532465e-7, 1e-19));
    expect(result.values['offTime'], closeTo(3.003246753246754e-7, 1e-19));
    expect(result.values['idleTime'], 1e-9);

    expect(result.values['outputPower'], 6.6);
    expect(
      result.values['inputPower'],
      closeTo(7.2727272727272725, 1e-14),
    );
    expect(
      result.values['diodeLosses'],
      closeTo(0.6727272727272728, 1e-14),
    );
    expect(
      result.values['inputAverageCurrent'],
      closeTo(1.0389610389610389, 1e-14),
    );

    expect(result.values['inductorAverageCurrent'], 2);
    expect(
      result.values['inductorRmsCurrent'],
      closeTo(2.004599115690954, 1e-13),
    );
    expect(
      result.values['mosfetRmsCurrent'],
      closeTo(1.4448147528098954, 1e-13),
    );
    expect(
      result.values['diodeRmsCurrent'],
      closeTo(1.3895783334133545, 1e-13),
    );
    expect(
      result.values['inputCapacitorRmsCurrent'],
      closeTo(1.0048751039660124, 1e-13),
    );
    expect(
      result.values['outputCapacitorRmsCurrent'],
      closeTo(0.1576295746754439, 1e-13),
    );

    expect(result.values['mosfetVoltageMax'], 7.7);
    expect(result.values['diodeVoltageMin'], -7);
    expect(result.values['inductorVoltageMin'], -4.0);
    expect(result.values['inductorVoltageMax'], 3.7);
  });
}

/// Expands the seven original Java per-cycle samples into Graph.java's
/// first 20 plotted points; the final 21st source point is intentionally cut.
List<double> _expandJavaBuckSamples(List<dynamic> sourceSamples) {
  final p = sourceSamples.map((value) => (value as num).toDouble()).toList();
  return [
    ...p,
    p[0],
    p[2],
    p[3],
    p[4],
    p[5],
    p[6],
    p[0],
    p[2],
    p[3],
    p[4],
    p[5],
    p[6],
    p[0],
    p[2],
  ].take(20).toList();
}
