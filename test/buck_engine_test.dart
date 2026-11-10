import 'dart:math' as math;
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
    expect(result.values['inputPower'], closeTo(
      result.values['outputPower']! + result.values['diodeLosses']!, 1e-9));
    expect(result.warnings, isEmpty);
  });

  test('Buck CCM RMS and device stresses match closed-form TI integrals', () {
    final input = BuckInputs.defaults();
    final r = buck.calculate(input);
    expect(r.isValid, isTrue);
    final d = r.values['onFraction']!;
    final i = input.outputCurrent;
    final di = r.values['rippleCurrent']!;
    final onTime = r.values['onTime']!;
    final offTime = r.values['offTime']!;
    final idleTime = r.values['idleTime']!;
    final integrationPeriod = onTime + offTime + idleTime;
    final onIntegralFraction = onTime / integrationPeriod;
    final offIntegralFraction = offTime / integrationPeriod;
    final activeIntegralFraction = (onTime + offTime) / integrationPeriod;
    final triangularCurrentIntegral = i * i + di * di / 12;
    expect(r.values['inductorAverageCurrent'], closeTo(i, 1e-10));
    expect(r.values['inductorRmsCurrent'], closeTo(
        math.sqrt(activeIntegralFraction * triangularCurrentIntegral), 1e-10));
    expect(r.values['mosfetAverageCurrent'], closeTo(i * d, 1e-10));
    expect(r.values['mosfetRmsCurrent'], closeTo(
        math.sqrt(onIntegralFraction * triangularCurrentIntegral), 1e-10));
    expect(r.values['diodeAverageCurrent'], closeTo(i * (1 - d), 1e-10));
    expect(r.values['diodeRmsCurrent'], closeTo(
        math.sqrt(offIntegralFraction * triangularCurrentIntegral), 1e-10));
    expect(r.values['mosfetVoltageMax'],
        closeTo(r.values['operatingInputVoltage']! + input.diodeForwardVoltage, 1e-12));
    expect(r.values['diodeVoltageMin'],
        closeTo(-r.values['operatingInputVoltage']!, 1e-12));
    expect(r.values['outputCapacitorRmsCurrent'], closeTo(di / math.sqrt(12), 1e-10));
  });

  test('Buck input capacitor RMS uses TI Java off-current definition in CCM', () {
    final input = BuckInputs.defaults();
    final r = buck.calculate(input);
    expect(r.isValid, isTrue);
    final onTime = r.values['onTime']!;
    final offTime = r.values['offTime']!;
    final idleTime = r.values['idleTime']!;
    final integrationPeriod = onTime + offTime + idleTime;
    final on = onTime / integrationPeriod;
    final off = offTime / integrationPeriod;
    final iin = r.values['inputAverageCurrent']!;
    final imin = r.values['minimumCurrent']!;
    final imax = r.values['peakCurrent']!;
    final ifetAvg = r.values['mosfetAverageCurrent']!;
    final onIntegral = (iin - imin) * (iin - imax) +
        (imax - imin) * (imax - imin) / 3;
    final expected = math.sqrt(on * onIntegral + off * ifetAvg * ifetAvg);
    expect(r.values['inputCapacitorRmsCurrent'], closeTo(expected, 1e-10));
  });

  test('Buck custom small inductor DCM RMS currents and intervals match TI integrals', () {
    const input = BuckInputs(
      inputVoltageMin: 9, inputVoltageMax: 16, outputVoltage: 5,
      outputCurrent: 2, switchingFrequency: 100e3, rippleFraction: 0.30,
      diodeForwardVoltage: 0.7, operatingInputVoltage: 16,
      selectedInductance: 3e-6,
    );
    final r = buck.calculate(input);
    expect(r.isValid, isTrue);
    expect(r.values['isCcm'], 0);
    expect(r.warnings, contains('Actual inductor ripple exceeds the requested ripple target.'));
    final peak = r.values['peakCurrent']!;
    final on = r.values['onFraction']!;
    final off = r.values['offFraction']!;
    expect(r.values['mosfetRmsCurrent'], closeTo(peak * math.sqrt(on / 3), 1e-10));
    expect(r.values['diodeRmsCurrent'], closeTo(peak * math.sqrt(off / 3), 1e-10));
    expect(r.values['inductorRmsCurrent'], closeTo(peak * math.sqrt((on + off) / 3), 1e-10));
    expect(r.values['mosfetAverageCurrent'], closeTo(peak * on / 2, 1e-10));
    expect(r.values['diodeAverageCurrent'], closeTo(peak * off / 2, 1e-10));
    expect(on + off + r.values['idleFraction']!, closeTo(1, 1e-10));
    expect(r.values['inductorAverageCurrent'], closeTo(input.outputCurrent, 1e-9));
  });


  test('Buck load slider matches the original PSD5 Java interpolation and runtime', () {
    BuckInputs atLoad(double percent) => BuckInputs(
      inputVoltageMin: 18,
      inputVoltageMax: 36,
      outputVoltage: 12,
      outputCurrent: 5,
      switchingFrequency: 200e3,
      rippleFraction: 0.30,
      diodeForwardVoltage: 0.5,
      operatingInputVoltage: 18,
      operatingLoadPercent: percent,
      selectedInductance: 33e-6,
    );

    final lightLoad = buck.calculate(atLoad(0));
    final halfSlider = buck.calculate(atLoad(50));
    final fullLoad = buck.calculate(atLoad(100));

    expect(lightLoad.isValid, isTrue);
    expect(halfSlider.isValid, isTrue);
    expect(fullLoad.isValid, isTrue);

    // WorkingSheet/Buck.java maps slider 0..100 to 1%..100% of rated dIout.
    expect(lightLoad.values['operatingOutputCurrent'], closeTo(0.05, 1e-14));
    expect(halfSlider.values['operatingOutputCurrent'], closeTo(2.525, 1e-14));
    expect(fullLoad.values['operatingOutputCurrent'], closeTo(5.0, 1e-14));

    // Fixed values from two calculate() passes on the original PSD5.jar Buck
    // class under OpenJDK 21; expected values are not generated by BuckEngine.
    expect(lightLoad.values['isCcm'], 0);
    expect(lightLoad.values['onTime'], closeTo(1.3631243920156768e-6, 1e-15));
    expect(lightLoad.values['offTime'], closeTo(6.542997081675247e-7, 1e-15));
    expect(lightLoad.values['idleTime'], closeTo(2.982575899816799e-6, 1e-15));
    expect(lightLoad.values['outputPower'], closeTo(0.6, 1e-12));
    expect(lightLoad.values['inputPower'], closeTo(0.6081081081081082, 1e-12));
    expect(lightLoad.values['inputAverageCurrent'], closeTo(0.03378378378378379, 1e-12));
    expect(lightLoad.values['mosfetAverageCurrent'], closeTo(0.033783783783783786, 1e-12));
    expect(lightLoad.values['mosfetRmsCurrent'], closeTo(0.07471278315860119, 1e-12));
    expect(lightLoad.values['diodeAverageCurrent'], closeTo(0.016216216216216214, 1e-12));
    expect(lightLoad.values['diodeRmsCurrent'], closeTo(0.05176253456222944, 1e-12));
    expect(lightLoad.values['inductorAverageCurrent'], closeTo(0.05, 1e-12));
    expect(lightLoad.values['inductorRmsCurrent'], closeTo(0.09089202358628705, 1e-12));
    expect(lightLoad.values['inputCapacitorRmsCurrent'], closeTo(0.06663824667977625, 1e-12));
    expect(lightLoad.values['outputCapacitorRmsCurrent'], closeTo(0.07590362278317261, 1e-12));

    expect(halfSlider.values['isCcm'], 1);
    expect(halfSlider.values['onTime'], closeTo(3.3783783783783788e-6, 1e-15));
    expect(halfSlider.values['offTime'], closeTo(1.6216216216216216e-6, 1e-15));
    expect(halfSlider.values['outputPower'], closeTo(30.3, 1e-12));
    expect(halfSlider.values['inputPower'], closeTo(30.709459459459456, 1e-11));
    expect(halfSlider.values['mosfetRmsCurrent'], closeTo(2.0804407387120762, 1e-12));
    expect(halfSlider.values['diodeAverageCurrent'], closeTo(0.8189189189189189, 1e-12));
    expect(halfSlider.values['diodeRmsCurrent'], closeTo(1.4413716246341775, 1e-12));
    expect(halfSlider.values['inputCapacitorRmsCurrent'], closeTo(1.1908413152875912, 1e-12));
    expect(halfSlider.values['inductorRmsCurrent'], closeTo(2.5309653943887533, 1e-12));

    // Lmin and the requested ripple target remain tied to rated dIout.
    expect(lightLoad.values['minimumInductance'], halfSlider.values['minimumInductance']);
    expect(halfSlider.values['minimumInductance'], fullLoad.values['minimumInductance']);
    expect(lightLoad.values['designRippleCurrent'], halfSlider.values['designRippleCurrent']);
    expect(halfSlider.values['designRippleCurrent'], fullLoad.values['designRippleCurrent']);

    expect(buck.calculate(atLoad(-0.01)).isValid, isFalse);
    expect(buck.calculate(atLoad(100.01)).isValid, isFalse);
  });

  test('Buck actual ripple percentage matches original PSD5.jar general()', () {
    BuckInputs atLoad(double percent) => BuckInputs(
      inputVoltageMin: 18,
      inputVoltageMax: 36,
      outputVoltage: 12,
      outputCurrent: 5,
      switchingFrequency: 200e3,
      rippleFraction: 0.30,
      diodeForwardVoltage: 0.5,
      operatingInputVoltage: 18,
      operatingLoadPercent: percent,
      selectedInductance: 33e-6,
    );

    final lightLoad = buck.calculate(atLoad(0));
    final halfLoad = buck.calculate(atLoad(50));
    final fullLoad = buck.calculate(atLoad(100));
    expect(lightLoad.values['rippleCurrent'], closeTo(0.24784079854830485, 1e-14));
    expect(lightLoad.values['actualRipplePercent'], closeTo(495.68159709660966, 1e-10));
    expect(halfLoad.values['rippleCurrent'], closeTo(0.6142506142506141, 1e-14));
    expect(halfLoad.values['actualRipplePercent'], closeTo(24.326757000024323, 1e-10));
    expect(fullLoad.values['rippleCurrent'], closeTo(0.614250614250615, 1e-14));
    expect(fullLoad.values['actualRipplePercent'], closeTo(12.2850122850123, 1e-10));

    const dcmInput = BuckInputs(
      inputVoltageMin: 9,
      inputVoltageMax: 16,
      outputVoltage: 5,
      outputCurrent: 2,
      switchingFrequency: 100e3,
      rippleFraction: 0.30,
      diodeForwardVoltage: 0.7,
      operatingInputVoltage: 16,
      selectedInductance: 3e-6,
    );
    final dcm = buck.calculate(dcmInput);
    expect(dcm.values['isCcm'], 0);
    expect(dcm.values['rippleCurrent'], closeTo(7.075300717250182, 1e-12));
    expect(dcm.values['actualRipplePercent'], closeTo(353.76503586250914, 1e-10));
  });

  test('Buck preserves the original tiny negative DCM idle interval', () {
    const input = BuckInputs(
      inputVoltageMin: 1234.828745840055,
      inputVoltageMax: 1234.828745840055,
      outputVoltage: 64.85314923063801,
      outputCurrent: 0.2691222643063725,
      switchingFrequency: 1066525.6129373105,
      rippleFraction: 0.30,
      diodeForwardVoltage: 4.997580342410744,
      operatingInputVoltage: 1234.828745840055,
      operatingLoadPercent: 100,
      selectedInductance: 0.00011482487534775702,
    );

    final result = buck.calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['isCcm'], 0);
    expect(
      result.values['idleTime'],
      closeTo(-1.0587911840678754e-22, 1e-35),
    );
    expect(
      result.values['onTime'],
      closeTo(5.282491453982283e-8, 1e-20),
    );
    expect(
      result.values['offTime'],
      closeTo(8.847990748605887e-7, 1e-20),
    );
    expect(
      result.values['inputCapacitorRmsCurrent'],
      closeTo(0.07218536194501951, 1e-13),
    );
    expect(
      result.values['outputCapacitorRmsCurrent'],
      closeTo(0.15537781174220577, 1e-13),
    );
  });

  test('Buck warns when a custom CCM inductor violates the original ripple check', () {
    const input = BuckInputs(
      inputVoltageMin: 18,
      inputVoltageMax: 36,
      outputVoltage: 12,
      outputCurrent: 5,
      switchingFrequency: 200e3,
      rippleFraction: 0.30,
      diodeForwardVoltage: 0.5,
      operatingInputVoltage: 18,
      selectedInductance: 5e-6,
    );
    final result = buck.calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['isCcm'], 1);
    expect(result.values['rippleCurrent']! * 0.99,
        greaterThan(input.outputCurrent * input.rippleFraction));
    expect(result.warnings, contains('Actual inductor ripple exceeds the requested ripple target.'));
    expect(result.values['peakCurrent'], greaterThan(0));
  });

  // Expected values below were captured by executing the original
  // com.ti.switchingpowersupplydesign.sheets.Buck class from PSD5.jar.
  // The oracle runs calculate() twice after changing inputs because the
  // original userCalculate() evaluates actualValues() before general()
  // refreshes iin; the second pass is the settled steady-input result.
  test('Buck CCM matches original PSD5.jar runtime oracle', () {
    const input = BuckInputs(
      inputVoltageMin: 18,
      inputVoltageMax: 36,
      outputVoltage: 12,
      outputCurrent: 5,
      switchingFrequency: 200e3,
      rippleFraction: 0.30,
      diodeForwardVoltage: 0.5,
      operatingInputVoltage: 18,
      selectedInductance: 33e-6,
    );
    final r = buck.calculate(input);
    expect(r.isValid, isTrue);
    expect(r.values['isCcm'], 1);
    expect(r.values['rippleCurrent'], closeTo(0.6142506142506142, 1e-12));
    expect(r.values['dutyCycle'], closeTo(0.6756756756756758, 1e-12));
    expect(r.values['onTime'], closeTo(3.3783783783783788e-6, 1e-18));
    expect(r.values['offTime'], closeTo(1.6216216216216216e-6, 1e-18));
    expect(r.values['idleTime'], 1e-9);
    expect(r.values['inductorRmsCurrent'], closeTo(5.002642971212262, 1e-12));
    expect(r.values['mosfetRmsCurrent'], closeTo(4.112147191587798, 1e-12));
    expect(r.values['diodeRmsCurrent'], closeTo(2.8489791456126947, 1e-12));
    expect(r.values['inputCapacitorRmsCurrent'], closeTo(2.344908588716427, 1e-12));
    expect(r.values['outputCapacitorRmsCurrent'], closeTo(0.17731887874374277, 1e-12));
    expect(r.values['inputPower'], closeTo(60.810810810810814, 1e-11));
    expect(r.values['inputAverageCurrent'], closeTo(3.3783783783783785, 1e-12));
  });

  test('Buck DCM matches original PSD5.jar runtime oracle', () {
    const input = BuckInputs(
      inputVoltageMin: 9,
      inputVoltageMax: 16,
      outputVoltage: 5,
      outputCurrent: 2,
      switchingFrequency: 100e3,
      rippleFraction: 0.30,
      diodeForwardVoltage: 0.7,
      operatingInputVoltage: 16,
      selectedInductance: 3e-6,
    );
    final r = buck.calculate(input);
    expect(r.isValid, isTrue);
    expect(r.values['isCcm'], 0);
    // In DCM the engine reports the physical 0-to-peak excursion; TI's
    // separate iripple_buck field remains the CCM design-ripple estimate.
    expect(r.values['rippleCurrent'], closeTo(7.075300717250182, 1e-11));
    expect(r.values['designRippleCurrent'], closeTo(12.51497005988024, 1e-11));
    expect(r.values['peakCurrent'], closeTo(7.075300717250182, 1e-11));
    expect(r.values['dutyCycle'], closeTo(0.1929627468340959, 1e-12));
    expect(r.values['onTime'], closeTo(1.929627468340959e-6, 1e-18));
    expect(r.values['offTime'], closeTo(3.7238424827632533e-6, 1e-18));
    expect(r.values['idleTime'], closeTo(4.3465300488957885e-6, 1e-18));
    expect(r.values['inductorAverageCurrent'], closeTo(2.0, 1e-12));
    expect(r.values['inductorRmsCurrent'], closeTo(3.071438472388289, 1e-12));
    expect(r.values['mosfetAverageCurrent'], closeTo(0.682634730538922, 1e-12));
    expect(r.values['mosfetRmsCurrent'], closeTo(1.7944072370566497, 1e-12));
    expect(r.values['diodeAverageCurrent'], closeTo(1.3173652694610771, 1e-12));
    expect(r.values['diodeRmsCurrent'], closeTo(2.4927568989505624, 1e-12));
    expect(r.values['inputCapacitorRmsCurrent'], closeTo(1.6594900292147985, 1e-12));
    expect(r.values['outputCapacitorRmsCurrent'], closeTo(2.3310371703743615, 1e-12));
    expect(r.values['inputPower'], closeTo(10.922155688622754, 1e-12));
  });

  test('Buck CCM/DCM transition equality matches original PSD5.jar', () {
    const input = BuckInputs(
      inputVoltageMin: 9,
      inputVoltageMax: 16,
      outputVoltage: 5,
      outputCurrent: 2,
      switchingFrequency: 100e3,
      rippleFraction: 0.30,
      diodeForwardVoltage: 0.7,
      operatingInputVoltage: 16,
      selectedInductance: 9.38622754491018e-6,
    );
    final r = buck.calculate(input);
    expect(r.isValid, isTrue);
    // Original checkForCCMDCCM() uses <=, so equality is classified as CCM.
    expect(r.values['isCcm'], 1);
    expect(r.values['rippleCurrent'], closeTo(4.0, 1e-12));
    expect(r.values['minimumCurrent'], closeTo(0.0, 1e-12));
    expect(r.values['idleTime'], 1e-9);
    expect(r.values['inductorRmsCurrent'], closeTo(2.3092856153641974, 1e-12));
    expect(r.values['mosfetRmsCurrent'], closeTo(1.3491394530258, 1e-12));
    expect(r.values['diodeRmsCurrent'], closeTo(1.8741992395733291, 1e-12));
    expect(r.values['outputCapacitorRmsCurrent'], closeTo(1.1547005383792515, 1e-12));
  });

  test('Buck classifier matches Java on adjacent boundary inductances', () {
    BuckInputs atInductance(double inductance) => BuckInputs(
      inputVoltageMin: 18,
      inputVoltageMax: 36,
      outputVoltage: 12,
      outputCurrent: 5,
      switchingFrequency: 200e3,
      rippleFraction: 0.30,
      diodeForwardVoltage: 0.5,
      operatingInputVoltage: 18,
      selectedInductance: inductance,
    );
    final justBelow = buck.calculate(atInductance(2.0270270270270264e-6));
    final justAbove = buck.calculate(atInductance(2.0270270270270273e-6));

    expect(justBelow.isValid, isTrue);
    expect(justAbove.isValid, isTrue);
    expect(justBelow.values['designRippleCurrent'], greaterThan(10));
    expect(justBelow.values['isCcm'], 0);
    expect(justAbove.values['designRippleCurrent'], 10);
    expect(justAbove.values['isCcm'], 1);
    expect(justAbove.values['minimumCurrent'], closeTo(0, 1e-12));
    expect(justAbove.values['idleTime'], 1e-9);
  });

  test('Buck enforces the original TI PSD input and operating limits', () {
    final d = BuckInputs.defaults();
    BuckInputs changed({
      double? vinMin, double? vinMax, double? vo, double? io,
      double? fs, double? ripple, double? vf, double? inductance,
    }) => BuckInputs(
      inputVoltageMin: vinMin ?? d.inputVoltageMin,
      inputVoltageMax: vinMax ?? d.inputVoltageMax,
      outputVoltage: vo ?? d.outputVoltage,
      outputCurrent: io ?? d.outputCurrent,
      switchingFrequency: fs ?? d.switchingFrequency,
      rippleFraction: ripple ?? d.rippleFraction,
      diodeForwardVoltage: vf ?? d.diodeForwardVoltage,
      selectedInductance: inductance,
    );

    expect(buck.calculate(changed(vinMax: 10000.01)).isValid, isFalse);
    expect(buck.calculate(changed(vo: 10000.01)).isValid, isFalse);
    expect(buck.calculate(changed(io: 1000.01)).isValid, isFalse);
    expect(buck.calculate(changed(fs: 10000001)).isValid, isFalse);
    expect(buck.calculate(changed(vf: 5.01)).isValid, isFalse);
    expect(buck.calculate(changed(ripple: 1.01)).isValid, isFalse);
    expect(buck.calculate(changed(inductance: 0.002200001)).isValid, isFalse);

    // Original PSD5 Buck.java rejects Vo > VinMin, not equality. At equality
    // the source's calculated duty is exactly 100%, which checkDutyCycle allows.
    expect(
      buck.calculate(changed(vinMin: 5, vinMax: 8, vo: 5, vf: 5)).isValid,
      isTrue,
    );
  });

  test('Buck rejects invalid operating input voltage', () {
    final d = BuckInputs.defaults();
    final invalid = BuckInputs(
      inputVoltageMin: d.inputVoltageMin, inputVoltageMax: d.inputVoltageMax,
      outputVoltage: d.outputVoltage, outputCurrent: d.outputCurrent,
      switchingFrequency: d.switchingFrequency, rippleFraction: d.rippleFraction,
      diodeForwardVoltage: d.diodeForwardVoltage,
      operatingInputVoltage: d.inputVoltageMax + 1,
    );
    expect(buck.calculate(invalid).isValid, isFalse);
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
      inputVoltageMin: 9, inputVoltageMax: 16, outputVoltage: 24,
      outputCurrent: 2, diodeForwardVoltage: 0.7,
      switchingFrequency: 100e3, rippleFraction: 0.30,
      operatingInputVoltage: 16, selectedInductance: 5e-6,
    );
    final result = boost.calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['isCcm'], 0);
    expect(result.values['minimumCurrent'], 0);
    expect(result.values['idleFraction'], greaterThan(0));
    final averageDiodeCurrent = result.values['peakCurrent']! * result.values['offFraction']! / 2;
    expect(averageDiodeCurrent, closeTo(input.outputCurrent, 1e-9));
    expect(result.values['onFraction']! + result.values['offFraction']! +
        result.values['idleFraction']!, closeTo(1, 1e-9));
  });

  test('Boost includes diode drop in duty and input power', () {
    const input = BoostInputs(
      inputVoltageMin: 9, inputVoltageMax: 16, outputVoltage: 24,
      outputCurrent: 2, switchingFrequency: 100e3, rippleFraction: 0.30,
      diodeForwardVoltage: 0.7, operatingInputVoltage: 12,
    );
    final result = boost.calculate(input);
    expect(result.isValid, isTrue);
    expect(result.values['dutyCycle'], closeTo(1 - 12 / 24.7, 1e-12));
    expect(result.values['inputAverageCurrent'], closeTo(24.7 * 2 / 12, 1e-12));
    expect(result.values['diodeLosses'], closeTo(1.4, 1e-12));
    expect(result.values['inputPower'], closeTo(
      result.values['outputPower']! + result.values['diodeLosses']!, 1e-9));
  });

  test('Boost rejects an output voltage that is not above input', () {
    const input = BoostInputs(
      inputVoltageMin: 12, inputVoltageMax: 24, outputVoltage: 24,
      outputCurrent: 2, switchingFrequency: 100e3, rippleFraction: 0.3,
    );
    expect(boost.calculate(input).isValid, isFalse);
  });
}
