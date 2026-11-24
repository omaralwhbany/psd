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

    test('matches OpenJDK 21 adjacent binary64 rounding boundaries', () {
      const cases = <(String, String, String)>[
        ('0.004999999999999999', '0.005', '0.00'),
        ('0.005', '0.005', '0.01'),
        ('0.005000000000000001', '0.005', '0.01'),
        ('0.014999999999999998', '0.015', '0.01'),
        ('0.015', '0.015', '0.01'),
        ('0.015000000000000001', '0.015', '0.02'),
        ('0.024999999999999998', '0.025', '0.02'),
        ('0.025', '0.025', '0.03'),
        ('1.1249999999999998', '1.125', '1.12'),
        ('1.125', '1.125', '1.12'),
        ('1.1250000000000002', '1.125', '1.13'),
        ('1.3749999999999998', '1.375', '1.37'),
        ('1.375', '1.375', '1.38'),
        ('1.3750000000000002', '1.375', '1.38'),
        ('9.994999999999997', '9.995', '9.99'),
        ('9.995', '9.995', '9.99'),
        ('9.995000000000001', '9.995', '10.00'),
        ('99.99499999999999', '99.995', '99.99'),
        ('99.995', '99.995', '100.00'),
        ('999.9949999999999', '999.995', '999.99'),
        ('999.995', '999.995', '1000.00'),
        ('4.5035996273704955e15', '4503599627370495.50',
          '4503599627370495.50'),
        ('4.503599627370496e15', '4503599627370496.00',
          '4503599627370496.00'),
        ('4.503599627370497e15', '4503599627370497.00',
          '4503599627370497.00'),
        ('4.6116860184273874e18', '4611686018427387400.00',
          '4611686018427387400.00'),
        ('4.611686018427388e18', '4611686018427387900.00',
          '4611686018427387900.00'),
        ('4.611686018427389e18', '4611686018427388900.00',
          '4611686018427388900.00'),
        ('9.223372036854775e18', '9223372036854774800.00',
          '9223372036854774800.00'),
        ('9.223372036854776e18', '9223372036854776000.00',
          '9223372036854776000.00'),
        ('1e23', '99999999999999990000000.00',
          '99999999999999990000000.00'),
        ('1e24', '1000000000000000000000000.00',
          '1000000000000000000000000.00'),
        ('1e25', '10000000000000000000000000.00',
          '10000000000000000000000000.00'),
        ('1e26', '100000000000000000000000000.00',
          '100000000000000000000000000.00'),
      ];

      for (final testCase in cases) {
        final value = double.parse(testCase.$1);
        expect(
          formatBuckJavaDecimal(
            value,
            minFractionDigits: 2,
            maxFractionDigits: 6,
          ),
          testCase.$2,
          reason: 'OpenJDK 21 #0.00#### oracle',
        );
        expect(
          formatBuckJavaDecimal(
            value,
            minFractionDigits: 2,
            maxFractionDigits: 2,
          ),
          testCase.$3,
          reason: 'OpenJDK 21 #0.00 oracle',
        );
      }

      expect(
        formatBuckJavaDecimal(
          double.parse('4.9e-324'),
          minFractionDigits: 2,
          maxFractionDigits: 2,
        ),
        '0.00',
      );
      expect(
        formatBuckJavaDecimal(
          double.parse('1e-300'),
          minFractionDigits: 2,
          maxFractionDigits: 2,
        ),
        '0.00',
      );
      final oneE300 = '1' + List<String>.filled(300, '0').join() + '.00';
      expect(
        formatBuckJavaDecimal(
          double.parse('1e300'),
          minFractionDigits: 2,
          maxFractionDigits: 2,
        ),
        oneE300,
      );

      expect(
        buckJavaGraphLabelKeepsMilliPrefix(
          double.parse('0.9999994999999999'),
        ),
        isTrue,
      );
      expect(
        buckJavaGraphLabelKeepsMilliPrefix(double.parse('0.9999995')),
        isFalse,
      );
      expect(
        buckJavaGraphLabelKeepsMilliPrefix(
          double.parse('0.9999995000000002'),
        ),
        isFalse,
      );
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
