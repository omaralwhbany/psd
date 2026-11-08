import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/core/waveform_chart.dart';
import 'package:psd/topologies/buck/buck_engine.dart';
import 'package:psd/topologies/buck/buck_inputs.dart';
import 'package:psd/topologies/buck/buck_waveforms.dart';

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
  test('five Buck CCM device traces match PSD5 graph transition levels', () {
    final input = BuckInputs.defaults();
    final result = const BuckEngine().calculate(input);
    expect(result.isValid, isTrue);
    final set = BuckWaveformSet.fromCalculation(input: input, values: result.values);
    expect(set.devices.map((d) => d.id).toList(), [
      'inputCapacitor', 'mosfet', 'inductor', 'diode', 'outputCapacitor',
    ]);
    for (final device in set.devices) {
      expect(device.voltage, hasLength(21));
      expect(device.current, hasLength(21));
    }
    final vin = result.values['operatingInputVoltage']!;
    final vo = input.outputVoltage;
    final vf = input.diodeForwardVoltage;
    final peak = result.values['peakCurrent']!;
    final minimum = result.values['minimumCurrent']!;
    expect(set.devices[0].voltage.first.value, vin);
    expect(set.devices[0].current[0].value,
        closeTo(result.values['inputAverageCurrent']! - minimum, 1e-12));
    expect(set.devices[1].voltage[0].value, 0);
    expect(set.devices[1].voltage[3].value, vin + vf);
    expect(set.devices[1].current[2].value, peak);
    expect(set.devices[2].voltage[2].value, vin - vo);
    expect(set.devices[2].voltage[3].value, -vo - vf);
    expect(set.devices[2].current[2].value, peak);
    expect(set.devices[2].current[4].value, minimum);
    expect(set.devices[3].voltage[0].value, -vin);
    expect(set.devices[3].voltage[3].value, vf);
    expect(set.devices[3].current[3].value, peak);
    expect(set.devices[3].current[4].value, minimum);
    expect(set.devices[4].voltage.first.value, vo);
    expect(set.devices[4].current[2].value,
        closeTo(peak - input.outputCurrent, 1e-12));
    final periodUs = 1e6 / input.switchingFrequency;
    expect(set.devices[2].voltage[7].timeMicroseconds,
        closeTo(periodUs + 0.001, 1e-9));
  });

  test('five Buck DCM device traces include source zero-current intervals', () {
    const input = BuckInputs(
      inputVoltageMin: 9, inputVoltageMax: 16, outputVoltage: 5,
      outputCurrent: 2, switchingFrequency: 100e3, rippleFraction: 0.30,
      diodeForwardVoltage: 0.7, operatingInputVoltage: 16,
      selectedInductance: 3e-6,
    );
    final result = const BuckEngine().calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['isCcm'], 0);
    final set = BuckWaveformSet.fromCalculation(input: input, values: result.values);
    expect(set.devices, hasLength(5));
    expect(set.devices[1].voltage[5].value, 11);
    expect(set.devices[1].current[4].value, 0);
    expect(set.devices[2].voltage[5].value, 0);
    expect(set.devices[2].current[4].value, 0);
    expect(set.devices[3].voltage[5].value, -5);
    expect(set.devices[3].current[4].value, 0);
    expect(set.devices[4].current[4].value, -2);
    expect(set.devices.first.voltage.every((p) => p.value == 16), isTrue);
    expect(set.devices.last.voltage.every((p) => p.value == 5), isTrue);
  });

  testWidgets('five Buck device waveform panels render on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final input = BuckInputs.defaults();
    final result = const BuckEngine().calculate(input);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BuckDeviceWaveformsView(
            waveforms: BuckWaveformSet.fromCalculation(input: input, values: result.values),
            voltageLabel: 'Voltage',
            currentLabel: 'Current',
            periodLabel: 'Three periods',
            deviceTitles: const {
              'inputCapacitor': 'Input capacitor Ci',
              'mosfet': 'MOSFET Q1',
              'inductor': 'Inductor L1',
              'diode': 'Freewheel diode D1',
              'outputCapacitor': 'Output capacitor Co',
            },
          ),
        ),
      ),
    ));
    for (final title in [
      'Input capacitor Ci', 'MOSFET Q1', 'Inductor L1',
      'Freewheel diode D1', 'Output capacitor Co',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

}
