import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/core/waveform_chart.dart';

void main() {
  testWidgets('waveform chart renders current and switch-node legends', (tester) async {
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
    expect(find.text('Inductor current'), findsOneWidget);
    expect(find.text('Switch-node voltage (normalized)'), findsOneWidget);
    expect(find.textContaining('Duty: 40.0%'), findsOneWidget);
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

    expect(find.textContaining('Duty: 65.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
