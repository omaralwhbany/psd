import 'dart:math' as math;

import '../../core/calculation_result.dart';
import '../../core/validation.dart';
import 'buck_inputs.dart';

class BuckEngine {
  const BuckEngine();

  CalculationResult calculate(BuckInputs input) {
    final errors = Validation.positiveValues({
      'Input voltage minimum': input.inputVoltageMin,
      'Input voltage maximum': input.inputVoltageMax,
      'Output voltage': input.outputVoltage,
      'Output current': input.outputCurrent,
      'Switching frequency': input.switchingFrequency,
      'Ripple fraction': input.rippleFraction,
    });
    if (input.inputVoltageMin > input.inputVoltageMax) errors.add('Input voltage minimum cannot exceed maximum.');
    if (input.rippleFraction > 1) errors.add('Ripple fraction must not exceed 1 (100%).');
    if (input.outputVoltage >= input.inputVoltageMin) errors.add('Buck output voltage must be below minimum input voltage.');
    if (input.diodeForwardVoltage < 0 || !input.diodeForwardVoltage.isFinite) errors.add('Diode forward voltage must be finite and non-negative.');
    final vin = input.operatingInputVoltage ?? input.inputVoltageMin;
    if (!vin.isFinite || vin < input.inputVoltageMin || vin > input.inputVoltageMax) {
      errors.add('Operating input voltage must be within the input voltage range.');
    }
    final selected = input.selectedInductance;
    if (selected != null && (!selected.isFinite || selected <= 0)) errors.add('Selected inductance must be greater than zero.');
    if (errors.isNotEmpty) return CalculationResult(values: const {}, errors: errors);

    final vo = input.outputVoltage;
    final vf = input.diodeForwardVoltage;
    final fs = input.switchingFrequency;
    final rippleTarget = input.outputCurrent * input.rippleFraction;

    // PSD-style design recommendation at maximum input voltage.
    final vinDesign = input.inputVoltageMax;
    final minimumInductance = ((vinDesign - vo) * (vo + vf)) /
        (fs * (vinDesign + vf) * rippleTarget);

    // Operating values follow the selected input-voltage point.
    final duty = (vo + vf) / (vin + vf);
    final inductanceUsed = selected ?? minimumInductance;
    final ripple = ((vin - vo) * duty) / (inductanceUsed * fs);
    final ccmMinimum = input.outputCurrent - ripple / 2;
    final isCcm = ccmMinimum >= 0;
    final period = 1 / fs;
    var onFraction = duty;
    var offFraction = 1 - duty;
    var idleFraction = 0.0;
    late final double peakCurrent;
    late final double minimumCurrent;
    late final double actualRipple;

    if (isCcm) {
      peakCurrent = input.outputCurrent + ripple / 2;
      minimumCurrent = ccmMinimum;
      actualRipple = ripple;
    } else {
      // Buck DCM: Iout = 0.5 * Ipeak * (ton + toff) / T.
      // Inductor slopes include the freewheel-diode forward drop.
      final ton = math.sqrt(
        2 * input.outputCurrent * inductanceUsed * (vo + vf) /
        (fs * (vin - vo) * (vin + vf)),
      );
      final toff = ton * (vin - vo) / (vo + vf);
      final tidle = period - ton - toff;
      if (!ton.isFinite || !toff.isFinite || tidle < -1e-12) {
        return CalculationResult(values: const {}, errors: const [
          'The selected inductance does not produce a valid Buck DCM cycle at this operating point.',
        ]);
      }
      onFraction = ton / period;
      offFraction = toff / period;
      idleFraction = (tidle / period).clamp(0.0, 1.0);
      peakCurrent = (vin - vo) * ton / inductanceUsed;
      minimumCurrent = 0;
      actualRipple = peakCurrent;
    }

    return CalculationResult(values: {
      'operatingInputVoltage': vin,
      'dutyCycle': duty,
      'minimumInductance': minimumInductance,
      'inductanceUsed': inductanceUsed,
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