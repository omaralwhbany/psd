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
    final vin = input.operatingInputVoltage ?? input.inputVoltageMin;
    if (!vin.isFinite || vin < input.inputVoltageMin || vin > input.inputVoltageMax) {
      errors.add('Operating input voltage must be within the input voltage range.');
    }
    final selected = input.selectedInductance;
    if (selected != null && (!selected.isFinite || selected <= 0)) errors.add('Selected inductance must be greater than zero.');
    if (errors.isNotEmpty) return CalculationResult(values: const {}, errors: errors);

    final vout = input.outputVoltage;
    final fs = input.switchingFrequency;
    final powerOut = vout * input.outputCurrent;

    // For fixed output power and a fixed ripple ratio of average input current,
    // L_required(Vin) = Vin^2 * (1 - Vin/Vout) / (fs * rippleFraction * Pout).
    // Its maximum occurs at 2/3 Vout, clamped to the specified input range.
    final criticalVin = (2 * vout / 3).clamp(input.inputVoltageMin, input.inputVoltageMax);
    final criticalDuty = 1 - criticalVin / vout;
    final criticalInputCurrent = powerOut / criticalVin;
    final rippleTarget = criticalInputCurrent * input.rippleFraction;
    final minimumInductance = criticalVin * criticalDuty / (fs * rippleTarget);

    final duty = 1 - vin / vout;
    final inputAverageCurrent = powerOut / vin;
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
      // Boost DCM: Iout is the average diode current during the off interval.
      final ton = math.sqrt(
        2 * input.outputCurrent * inductanceUsed * (vout - vin) /
        (vin * vin * fs),
      );
      final toff = ton * vin / (vout - vin);
      final tidle = period - ton - toff;
      if (!ton.isFinite || !toff.isFinite || tidle < -1e-12) {
        return CalculationResult(values: const {}, errors: const [
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