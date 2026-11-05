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
    final minimumCurrent = inputAverageCurrent - ripple / 2;
    final peakCurrent = inputAverageCurrent + ripple / 2;
    return CalculationResult(values: {
      'operatingInputVoltage': vin,
      'designInputVoltage': criticalVin,
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