import 'dart:math' as math;

import '../../core/calculation_result.dart';
import '../../core/validation.dart';
import 'boost_inputs.dart';

class BoostEngine {
  const BoostEngine();

  CalculationResult calculate(BoostInputs input) {
    final errors = Validation.positiveValues({
      'Input voltage minimum': input.inputVoltageMin,
      'Input voltage maximum': input.inputVoltageMax,
      'Output voltage': input.outputVoltage,
      'Output current': input.outputCurrent,
      'Switching frequency': input.switchingFrequency,
      'Ripple fraction': input.rippleFraction,
    });
    if (input.inputVoltageMin > input.inputVoltageMax) errors.add('Input voltage minimum cannot exceed maximum.');
    if (input.outputVoltage <= input.inputVoltageMax) errors.add('Boost output voltage must exceed maximum input voltage.');
    if (input.rippleFraction > 1) errors.add('Ripple fraction must not exceed 1 (100%).');
    if (!input.diodeForwardVoltage.isFinite || input.diodeForwardVoltage < 0) {
      errors.add('Diode forward voltage must be finite and non-negative.');
    }
    final vin = input.operatingInputVoltage ?? input.inputVoltageMin;
    if (!vin.isFinite || vin < input.inputVoltageMin || vin > input.inputVoltageMax) {
      errors.add('Operating input voltage must be within the input voltage range.');
    }
    final selected = input.selectedInductance;
    if (selected != null && (!selected.isFinite || selected <= 0)) errors.add('Selected inductance must be greater than zero.');
    if (errors.isNotEmpty) return CalculationResult(values: const {}, errors: errors);

    final vout = input.outputVoltage;
    final vf = input.diodeForwardVoltage;
    final effectiveOutput = vout + vf;
    final fs = input.switchingFrequency;
    final duty = (effectiveOutput - vin) / effectiveOutput;
    final powerOut = vout * input.outputCurrent;
    // The diode conducts the output current during the off interval.
    // This includes its forward-drop loss, matching TI's nonsynchronous model.
    final inputAverageCurrent = effectiveOutput * input.outputCurrent / vin;

    // Find the worst-case inductance requirement over the complete VIN range.
    // L = VIN * D / (fs * rippleFraction * IIN); its unconstrained maximum
    // occurs at VIN = 2/3 * (VOUT + VF).
    final criticalVin = (2 * effectiveOutput / 3)
        .clamp(input.inputVoltageMin, input.inputVoltageMax);
    final criticalDuty = 1 - criticalVin / effectiveOutput;
    final criticalInputCurrent = effectiveOutput * input.outputCurrent / criticalVin;
    final rippleTarget = criticalInputCurrent * input.rippleFraction;
    final minimumInductance = criticalVin * criticalDuty / (fs * rippleTarget);

    final inductanceUsed = selected ?? minimumInductance;
    final ripple = vin * duty / (inductanceUsed * fs);
    final ccmMinimum = inputAverageCurrent - ripple / 2;
    final isCcm = ccmMinimum >= 0;
    final period = 1 / fs;
    var onFraction = duty;
    var offFraction = 1 - duty;
    var idleFraction = 0.0;
    late final double minimumCurrent;
    late final double peakCurrent;
    late final double actualRipple;

    if (isCcm) {
      minimumCurrent = ccmMinimum;
      peakCurrent = inputAverageCurrent + ripple / 2;
      actualRipple = ripple;
    } else {
      // DCM: average diode current equals IOUT; current is triangular
      // during the off interval and zero during the idle interval.
      final ton = math.sqrt(
        2 * input.outputCurrent * inductanceUsed * effectiveOutput /
        (vin * vin * fs),
      );
      final toff = ton * vin / (effectiveOutput - vin);
      final tidle = period - ton - toff;
      if (!ton.isFinite || !toff.isFinite || tidle < -1e-12) {
        return const CalculationResult(values: {}, errors: [
          'The selected inductance does not produce a valid Boost DCM cycle at this operating point.',
        ]);
      }
      onFraction = ton / period;
      offFraction = toff / period;
      idleFraction = (tidle / period).clamp(0.0, 1.0);
      peakCurrent = vin * ton / inductanceUsed;
      minimumCurrent = 0;
      actualRipple = peakCurrent;
    }

    return CalculationResult(values: {
      'operatingInputVoltage': vin,
      'designInputVoltage': criticalVin,
      'dutyCycle': duty,
      'minimumInductance': minimumInductance,
      'inductanceUsed': inductanceUsed,
      'inputAverageCurrent': inputAverageCurrent,
      'inputPower': vin * inputAverageCurrent,
      'outputPower': powerOut,
      'diodeLosses': input.diodeForwardVoltage * input.outputCurrent,
      'rippleCurrent': actualRipple,
      'peakCurrent': peakCurrent,
      'minimumCurrent': minimumCurrent,
      'isCcm': isCcm ? 1 : 0,
      'onFraction': onFraction,
      'offFraction': offFraction,
      'idleFraction': idleFraction,
    });
  }
}
