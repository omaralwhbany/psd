import 'dart:math' as math;

import '../../core/calculation_result.dart';
import '../../core/validation.dart';
import 'buck_inputs.dart';

/// Ideal non-synchronous Buck model aligned with TI PSD's Java Buck model.
/// Diode forward drop is included; parasitic losses and switching transients
/// are intentionally excluded.
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
    if (!vin.isFinite || vin < input.inputVoltageMin || vin > input.inputVoltageMax) errors.add('Operating input voltage must be within the input voltage range.');
    final selected = input.selectedInductance;
    if (selected != null && (!selected.isFinite || selected <= 0)) errors.add('Selected inductance must be greater than zero.');
    if (errors.isNotEmpty) return CalculationResult(values: const {}, errors: errors);

    final vo = input.outputVoltage;
    final vf = input.diodeForwardVoltage;
    final fs = input.switchingFrequency;
    final iout = input.outputCurrent;
    final period = 1 / fs;
    final rippleTarget = iout * input.rippleFraction;
    final vinDesign = input.inputVoltageMax;

    // Matches PSD Buck.calcMinInductance(): design at maximum input voltage.
    final minimumInductance = (vinDesign - vo) * (vo + vf) /
        (fs * (vinDesign + vf) * rippleTarget);
    final inductance = selected ?? minimumInductance;

    final dutyCcm = (vo + vf) / (vin + vf);
    final rippleCcm = (vin - vo) * dutyCcm / (inductance * fs);
    final isCcm = rippleCcm <= 2 * iout;

    late double ton;
    late double toff;
    late double tidle;
    late double peak;
    late double minimum;
    late double ripple;
    if (isCcm) {
      ton = dutyCcm * period;
      toff = period - ton;
      tidle = 0;
      peak = iout + rippleCcm / 2;
      minimum = iout - rippleCcm / 2;
      ripple = rippleCcm;
    } else {
      // Exact closed-form DCM timing used by PSD Buck.onofftimes().
      ton = math.sqrt(2 * iout * inductance * (vo + vf) /
          (fs * (vin - vo) * (vin + vf)));
      toff = ton * (vin - vo) / (vo + vf);
      tidle = period - ton - toff;
      if (!ton.isFinite || !toff.isFinite || tidle < -1e-12) {
        return const CalculationResult(values: {}, errors: [
          'The selected inductance does not produce a valid Buck DCM cycle at this operating point.',
        ]);
      }
      tidle = math.max(0, tidle);
      peak = (vin - vo) * ton / inductance;
      minimum = 0;
      ripple = peak;
    }

    final onFraction = ton / period;
    final offFraction = toff / period;
    final idleFraction = tidle / period;
    final currentIntegral = isCcm
        ? (peak * minimum + (peak - minimum) * (peak - minimum) / 3)
        : peak * peak / 3;

    // TI PSD Java actualValues(): per-device average and RMS currents.
    final fetAverage = isCcm ? iout * onFraction : peak * onFraction / 2;
    final fetRms = math.sqrt(onFraction * currentIntegral);
    final diodeAverage = isCcm ? iout * offFraction : peak * offFraction / 2;
    final diodeRms = math.sqrt(offFraction * currentIntegral);

    final inductorAverage = isCcm
        ? (minimum + peak) / 2
        : peak * (ton + toff) / (2 * period);
    final inductorRms = isCcm
        ? math.sqrt((ton + toff) / period * currentIntegral)
        : peak * math.sqrt((ton + toff) / (3 * period));

    // PSD Buck.java sets the input-capacitor off-interval current to
    // the MOSFET average current (iincap_off_buck = ifet_avg_buck).
    // Keep that source-specific definition in both CCM and DCM integrals.
    final outputPower = vo * iout;
    final diodeLoss = vf * diodeAverage;
    final inputPower = outputPower + diodeLoss;
    final inputAverage = inputPower / vin;
    final inputCapOffCurrent = fetAverage;
    final capInRmsSquared = isCcm
        ? onFraction * ((inputAverage - minimum) * (inputAverage - peak) +
                (peak - minimum) * (peak - minimum) / 3) +
            offFraction * inputCapOffCurrent * inputCapOffCurrent
        : onFraction * (inputAverage * (inputAverage - peak) +
                peak * peak / 3) +
            (offFraction + idleFraction) *
                inputCapOffCurrent * inputCapOffCurrent;
    final inputCapRms = math.sqrt(math.max(0, capInRmsSquared));

    // Output capacitor current iC = iL - Iout, integrated over each
    // linear interval. This reproduces the original PSD Java expression.
    final capOutRmsSquared = isCcm
        ? (ton + toff) * fs *
            ((ripple / 2) * (-ripple / 2) +
                ripple * ripple / 3)
        : ton * fs *
                ((peak - iout) * (-iout) + peak * peak / 3) +
            toff * fs *
                ((peak - iout) * (-iout) + peak * peak / 3) +
            tidle * fs * iout * iout;
    final outputCapRms = math.sqrt(math.max(0, capOutRmsSquared));

    final duty = onFraction;
    return CalculationResult(values: {
      'operatingInputVoltage': vin,
      'inputAverageCurrent': inputAverage,
      'inputPower': inputPower,
      'outputPower': outputPower,
      'diodeLosses': diodeLoss,
      'dutyCycle': duty,
      'minimumInductance': minimumInductance,
      'inductanceUsed': inductance,
      'rippleCurrent': ripple,
      'peakCurrent': peak,
      'minimumCurrent': minimum,
      'isCcm': isCcm ? 1 : 0,
      'onFraction': onFraction,
      'offFraction': offFraction,
      'idleFraction': idleFraction,
      'onTime': ton,
      'offTime': toff,
      'idleTime': tidle,
      'inductorAverageCurrent': inductorAverage,
      'inductorRmsCurrent': inductorRms,
      'inductorPeakCurrent': peak,
      'mosfetAverageCurrent': fetAverage,
      'mosfetRmsCurrent': fetRms,
      'mosfetPeakCurrent': peak,
      'mosfetVoltageMin': 0.0,
      'mosfetVoltageMax': vin + vf,
      'mosfetVoltageAtZeroCurrent': vin - vo,
      'diodeAverageCurrent': diodeAverage,
      'diodeRmsCurrent': diodeRms,
      'diodePeakCurrent': peak,
      'diodeVoltageMin': -vin,
      'diodeVoltageMax': vf,
      'diodeVoltageAtZeroCurrent': -vo,
      'inputCapacitorVoltageMin': vin,
      'inputCapacitorVoltageMax': vin,
      'outputCapacitorVoltageMin': vo,
      'outputCapacitorVoltageMax': vo,
      'inputCapacitorAverageCurrent': 0.0,
      'inputCapacitorRmsCurrent': inputCapRms,
      'outputCapacitorAverageCurrent': 0.0,
      'outputCapacitorRmsCurrent': outputCapRms,
      'inductorVoltageMin': -vo - vf,
      'inductorVoltageMax': vin - vo,
    });
  }
}
