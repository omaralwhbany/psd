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
      'Inductance': input.inductance,
    });
    if (input.inputVoltageMin > input.inputVoltageMax) errors.add('Input voltage minimum cannot exceed maximum.');
    if (input.rippleFraction > 1) errors.add('Ripple fraction must not exceed 1 (100%).');
    if (input.outputVoltage >= input.inputVoltageMin) errors.add('Buck output voltage must be below minimum input voltage.');
    if (input.diodeForwardVoltage < 0 || !input.diodeForwardVoltage.isFinite) errors.add('Diode forward voltage must be finite and non-negative.');
    if (errors.isNotEmpty) return CalculationResult(values: const {}, errors: errors);

    final vin = input.inputVoltageMax;
    final vo = input.outputVoltage;
    final vf = input.diodeForwardVoltage;
    final fs = input.switchingFrequency;
    final rippleTarget = input.outputCurrent * input.rippleFraction;
    final duty = (vo + vf) / (vin + vf);
    final minimumInductance = ((vin - vo) * (vo + vf)) / (fs * (vin + vf) * rippleTarget);
    final ripple = ((vin - vo) * duty) / (input.inductance * fs);
    final minimumCurrent = input.outputCurrent - ripple / 2;
    final peakCurrent = input.outputCurrent + ripple / 2;
    return CalculationResult(values: {
      'dutyCycle': duty,
      'minimumInductance': minimumInductance,
      'rippleCurrent': ripple,
      'peakCurrent': peakCurrent,
      'minimumCurrent': minimumCurrent,
      'isCcm': minimumCurrent >= 0 ? 1 : 0,
    });
  }
}
