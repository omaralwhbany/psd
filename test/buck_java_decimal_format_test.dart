import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_java_decimal_format.dart';
import 'package:psd/topologies/buck/buck_waveforms.dart';

void main() {
  group('OpenJDK 21 DecimalFormat compatibility', () {
    test('matches HALF_EVEN and binary64 tie behavior', () {
      String format(double value) => formatBuckJavaDecimal(
            value,
            minFractionDigits: 2,
            maxFractionDigits: 2,
          );

      expect(format(1.125), '1.12');
      expect(format(1.375), '1.38');
      expect(format(2.675), '2.67');
      expect(format(0.005), '0.01');
      expect(format(-0.0), '-0.00');
    });

    test('matches Buck six-place labels and Graph two-stage conversion', () {
      expect(
        formatBuckJavaDecimal(
          0.1234550000001,
          minFractionDigits: 2,
          maxFractionDigits: 6,
        ),
        '0.123455',
      );
      expect(
        buckJavaGraphLabelValue(0.1234550000001),
        0.123455,
      );
      expect(
        formatBuckJavaGraphMetric(0.1234550000001, 1000),
        '123.45',
      );
    });

    test('matches the original Buck large-current label from PSD5.jar', () {
      expect(
        formatBuckJavaDecimal(
          1.4237369936287484e46,
          minFractionDigits: 2,
          maxFractionDigits: 6,
        ),
        '14237369936287484000000000000000000000000000000.00',
      );
    });

    test('matches FloatingDecimal signed-long overflow rounding', () {
      expect(
        formatBuckJavaDecimal(
          2.5253627982831803e25,
          minFractionDigits: 2,
          maxFractionDigits: 2,
        ),
        '25253627982831802000000000.00',
      );
      expect(
        formatBuckJavaDecimal(
          -2.5253627982831803e25,
          minFractionDigits: 2,
          maxFractionDigits: 2,
        ),
        '-25253627982831802000000000.00',
      );
    });

    test('preserves Java non-finite symbols and SI-prefix comparisons', () {
      expect(
        formatBuckJavaDecimal(
          double.infinity,
          minFractionDigits: 2,
          maxFractionDigits: 2,
        ),
        '∞',
      );
      expect(
        formatBuckJavaDecimal(
          double.negativeInfinity,
          minFractionDigits: 2,
          maxFractionDigits: 2,
        ),
        '-∞',
      );
      expect(
        formatBuckJavaDecimal(
          double.nan,
          minFractionDigits: 2,
          maxFractionDigits: 2,
        ),
        'NaN',
      );
      expect(buckJavaGraphLabelKeepsMilliPrefix(0.9999994), isTrue);
      expect(buckJavaGraphLabelKeepsMilliPrefix(0.9999996), isFalse);
      expect(buckJavaGraphLabelKeepsMilliPrefix(double.nan), isTrue);
      expect(buckJavaGraphLabelKeepsMilliPrefix(double.infinity), isFalse);
    });
  });

  testWidgets(
    'Buck waveform metric labels use the original Java large-number output',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const metrics = BuckDeviceMetrics(
        minimumVoltage: 0.1,
        maximumVoltage: 0.2,
        minimumCurrent: 1.4237369936287484e46,
        maximumCurrent: 2.5253627982831803e25,
        rmsCurrent: 1.4237369936287484e46,
        averageCurrent: 2.5253627982831803e25,
        acCurrent: 1.4237369936287484e46,
      );
      const device = BuckDeviceWaveform(
        id: 'probe',
        title: 'Probe device',
        voltage: [
          BuckWaveformPoint(0, 0),
          BuckWaveformPoint(1, 1),
        ],
        current: [
          BuckWaveformPoint(0, 0),
          BuckWaveformPoint(1, 1),
        ],
        metrics: metrics,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BuckDeviceWaveformsView(
                waveforms: BuckWaveformSet([device]),
                voltageLabel: 'Voltage',
                currentLabel: 'Current',
                periodLabel: 'Three periods',
                timeAxisLabel: 'Time',
                deviceTitles: {'probe': 'Probe device'},
                metricLabels: {
                  'minimumVoltage': 'Minimum voltage',
                  'maximumVoltage': 'Maximum voltage',
                  'minimumCurrent': 'Minimum current',
                  'maximumCurrent': 'Maximum current',
                  'rmsCurrent': 'RMS current',
                  'averageCurrent': 'Average current',
                  'acCurrent': 'AC current',
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Minimum current: '
          '14237369936287484000000000000000000000000000000.00 A',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Maximum current: 25253627982831802000000000.00 A'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
