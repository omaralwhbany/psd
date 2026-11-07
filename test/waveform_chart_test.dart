import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/core/waveform_chart.dart';

void main() {
  test('Buck MOSFET voltage levels match PSD5 Buck.java', () {
    // Source: Buck.java actualValues() assigns vfet_min_buck = 0,
    // vfet_max_buck = Vin + Vf, and vfet_ind_cur_zero_buck = Vin - Vo.
    final levels = BuckMosfetVoltageLevels.fromOperatingPoint(
      inputVoltage: 12,
      outputVoltage: 5,
      diodeDrop: 0.7,
    );

    expect(levels.onState, 0);
    expect(levels.freewheel, closeTo(12.7, 1e-12));
    expect(levels.zeroCurrent, 7);
  });

  testWidgets('waveform chart renders current label and synchronized period', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PowerWaveformChart(
          averageCurrent: 5,
          rippleCurrent: 1.5,
          dutyCycle: 0.4,
          currentLabel: 'Buck inductor current',
          switchHighDuringOn: true,
        ),
      ),
    ));

    expect(find.text('Buck inductor current'), findsOneWidget);
    expect(find.textContaining('One switching period'), findsOneWidget);
    expect(find.textContaining('D = 40.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waveform chart handles narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(8),
          child: PowerWaveformChart(
            averageCurrent: 2,
            rippleCurrent: 0.8,
            dutyCycle: 0.65,
            currentLabel: 'Boost inductor current',
            switchHighDuringOn: false,
          ),
        ),
      ),
    ));

    expect(find.textContaining('D = 65.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
