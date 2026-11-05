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
    final selected = input.selectedInductance;
    if (selected != null && (!selected.isFinite || selected <= 0)) errors.add('Selected inductance must be greater than zero.');
    if (errors.isNotEmpty) return CalculationResult(values: const {}, errors: errors);

    // Ideal boost equations, evaluated at minimum input voltage (worst-case duty).
    final vin = input.inputVoltageMin;
    final duty = 1 - vin / input.outputVoltage;
    final inputAverageCurrent = input.outputVoltage * input.outputCurrent / vin;
    final rippleTarget = inputAverageCurrent * input.rippleFraction;
    final minimumInductance = vin * duty / (input.switchingFrequency * rippleTarget);
    final inductanceUsed = selected ?? minimumInductance;
    final ripple = vin * duty / (inductanceUsed * input.switchingFrequency);
    final minimumCurrent = inputAverageCurrent - ripple / 2;
    final peakCurrent = inputAverageCurrent + ripple / 2;
    return CalculationResult(values: {
      'dutyCycle': duty,
      'minimumInductance': minimumInductance,
      'inductanceUsed': inductanceUsed,
      'inputAverageCurrent': inputAverageCurrent,
      'rippleCurrent': ripple,
      'peakCurrent': peakCurrent,
      'minimumCurrent': minimumCurrent,
      'isCcm': minimumCurrent >= 0 ? 1 : 0,
    });
  }
}