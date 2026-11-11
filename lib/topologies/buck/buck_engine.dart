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
    // Match the input limits enforced by the original PSD5 Buck.java checks.
    if (input.inputVoltageMin > 10000 || input.inputVoltageMax > 10000) {
      errors.add('Input voltage must not exceed 10000 V.');
    }
    if (input.outputVoltage > 10000) errors.add('Output voltage must not exceed 10000 V.');
    if (input.outputCurrent > 1000) errors.add('Output current must not exceed 1000 A.');
    if (input.switchingFrequency > 1e7) errors.add('Switching frequency must not exceed 10 MHz.');
    if (input.rippleFraction > 1) errors.add('Ripple fraction must not exceed 1 (100%).');
    if (!input.operatingLoadPercent.isFinite ||
        input.operatingLoadPercent < 0 || input.operatingLoadPercent > 100) {
      errors.add('Operating load percentage must be between 0 and 100.');
    }
    if (input.outputVoltage > input.inputVoltageMin) errors.add('Buck output voltage must not exceed minimum input voltage.');
    if (input.diodeForwardVoltage < 0 || input.diodeForwardVoltage > 5 || !input.diodeForwardVoltage.isFinite) {
      errors.add('Diode forward voltage must be between 0 and 5 V.');
    }
    final vin = input.operatingInputVoltage ?? input.inputVoltageMin;
    if (!vin.isFinite || vin < input.inputVoltageMin || vin > input.inputVoltageMax) errors.add('Operating input voltage must be within the input voltage range.');
    final selected = input.selectedInductance;
    if (selected != null && (!selected.isFinite || selected <= 0)) errors.add('Selected inductance must be greater than zero.');
    if (selected != null && selected > 0.0022) errors.add('Selected inductance must not exceed 2200 µH.');
    if (errors.isNotEmpty) return CalculationResult(values: const {}, errors: errors);

    final vo = input.outputVoltage;
    final vf = input.diodeForwardVoltage;
    final fs = input.switchingFrequency;
    // Buck.java maps its 0..100% load slider onto ioutmin=1%..ioutmax=100%
    // of rated dIout. The rated current still defines Lmin and the ripple target.
    final ratedOutputCurrent = input.outputCurrent;
    final minimumLoadCurrent = 0.01 * ratedOutputCurrent;
    final iout = input.operatingLoadPercent / 100.0 *
            (ratedOutputCurrent - minimumLoadCurrent) +
        minimumLoadCurrent;
    final period = 1 / fs;
    final rippleTarget = ratedOutputCurrent * input.rippleFraction;
    final vinDesign = input.inputVoltageMax;

    // Matches PSD Buck.calcMinInductance(): design at maximum input voltage.
    final minimumInductance = (1 / fs) * (vinDesign - vo) *
        ((vo + vf) / (vinDesign + vf)) * (1 / rippleTarget);
    final inductance = selected ?? minimumInductance;

    final dutyCcm = (vo + vf) / (vin + vf);
    // PSD5 Buck.checkDutyCycle() rejects a calculated duty cycle above 100%.
    if (dutyCcm > 1) {
      return const CalculationResult(values: {}, errors: [
        'Buck duty cycle must not exceed 100% at the selected operating point.',
      ]);
    }
    final rippleCcm = (1 / fs) * (vin - vo) *
        ((vo + vf) / (vin + vf)) * (1 / inductance);
    final isCcm = rippleCcm <= 2 * iout;

    late double ton;
    late double toff;
    late double tidle;
    late double peak;
    late double minimum;
    if (isCcm) {
      ton = dutyCcm * period;
      toff = period - ton;
      // TI PSD Buck.onofftimes() uses a 1 ns numerical zero-current interval in CCM.
      tidle = 1e-9;
      peak = iout + rippleCcm / 2;
      minimum = iout - rippleCcm / 2;
    } else {
      // Exact closed-form DCM timing used by PSD Buck.onofftimes().
      ton = math.sqrt(2 * iout * inductance *
          ((vo + vf) / (fs * (vin - vo) * (vin + vf))));
      toff = ton * ((vin + vf) / (vo + vf)) - ton;
      tidle = period - ton - toff;
      if (!ton.isFinite || !toff.isFinite) {
        return const CalculationResult(values: {}, errors: [
          'The selected inductance does not produce a valid Buck DCM cycle at this operating point.',
        ]);
      }
      peak = (1 / inductance) * (vin - vo) * ton;
      minimum = 0;
    }

    // Java general() derives the displayed excursion after singleValues():
    // iripple = iind_max - iind_min. This can differ by an ulp from the
    // earlier CCM design-ripple estimate because the source performs the
    // two current additions/subtractions before taking their difference.
    final ripple = peak - minimum;

    // Java actualValues() normalizes device RMS integrals by t1+t2+t3.
    // Preserve the raw DCM t3 = period - ton - toff, including tiny negative
    // binary64 roundoff at the CCM/DCM boundary; Buck.java does not clamp it.
    final integrationPeriod = ton + toff + tidle;
    // Time fractions use the switching period, as used by TI's timing and
    // average-current equations. RMS integrals use t1+t2+t3, which differs
    // by the 1 ns CCM epsilon in the original Java implementation.
    final onFraction = ton / period;
    final offFraction = toff / period;
    final idleFraction = tidle / period;
    final onIntegralFraction = ton / integrationPeriod;
    final offIntegralFraction = toff / integrationPeriod;
    final activeIntegralFraction = (ton + toff) / integrationPeriod;
    final deviceCurrentIntegral = peak * minimum +
        0.3333333333333333 * ((peak - minimum) * (peak - minimum));
    final inductorCurrentIntegral = peak * minimum +
        (peak - minimum) * (peak - minimum) / 3.0;

    // Preserve Buck.java actualValues() operation order for average/RMS values.
    final fetAverage = isCcm
        ? (minimum + peak) / 2.0 * ton * fs
        : peak / 2.0 * ton * fs;
    final fetRms = isCcm
        ? math.sqrt(onIntegralFraction * deviceCurrentIntegral)
        : peak * math.sqrt(onIntegralFraction * 0.3333333333333333);
    final diodeAverage = isCcm
        ? (minimum + peak) / 2.0 * toff * fs
        : peak / 2.0 * toff * fs;
    final diodeRms = isCcm
        ? math.sqrt(offIntegralFraction * deviceCurrentIntegral)
        : peak * math.sqrt(offIntegralFraction * 0.3333333333333333);

    final inductorAverage = isCcm
        ? (minimum + peak) / 2.0
        : peak / 2.0 * (ton + toff) * fs;
    final inductorRms = isCcm
        ? math.sqrt(activeIntegralFraction * inductorCurrentIntegral)
        : peak * math.sqrt((ton + toff) / (3.0 / fs));

    // PSD Buck.java sets the input-capacitor off-interval current to
    // the MOSFET average current (iincap_off_buck = ifet_avg_buck).
    // Keep that source-specific definition in both CCM and DCM integrals.
    final outputPower = vo * iout;
    final diodeLoss = vf * diodeAverage;
    final inputPower = outputPower + diodeLoss;
    final inputAverage = inputPower / vin;
    final inputCapOffCurrent = fetAverage;
    // Match the exact current offsets and subtraction order in
    // Buck.actualValues() for the input-capacitor RMS integral.
    final inputCapMaxOn = isCcm ? -minimum + inputAverage : inputAverage;
    final inputCapMinOn = -peak + inputAverage;
    final inputCapOnDelta = inputCapMaxOn - inputCapMinOn;
    final inputCapOnIntegral = inputCapMaxOn * inputCapMinOn +
        inputCapOnDelta * inputCapOnDelta / 3.0;
    final capInRmsSquared = isCcm
        ? onIntegralFraction * inputCapOnIntegral +
            offIntegralFraction * inputCapOffCurrent * inputCapOffCurrent
        : onIntegralFraction * inputCapOnIntegral +
            ((toff + tidle) / integrationPeriod) *
                inputCapOffCurrent * inputCapOffCurrent;
    final inputCapRms = math.sqrt(capInRmsSquared);

    // Match Buck.actualValues()'s separate ON/OFF linear current integrals
    // for the output capacitor, including its DCM zero-current interval.
    final outputCapMaxOn = peak - iout;
    final outputCapMinOn = isCcm ? minimum - iout : -iout;
    final outputCapMaxOff = peak - iout;
    final outputCapMinOff = isCcm ? minimum - iout : -iout;
    final outputCapOnDelta = outputCapMaxOn - outputCapMinOn;
    final outputCapOffDelta = outputCapMaxOff - outputCapMinOff;
    final outputCapOnIntegral = outputCapMaxOn * outputCapMinOn +
        outputCapOnDelta * outputCapOnDelta / 3.0;
    final outputCapOffIntegral = outputCapMaxOff * outputCapMinOff +
        outputCapOffDelta * outputCapOffDelta / 3.0;
    final capOutRmsSquared = isCcm
        ? (ton + toff) * fs * outputCapOnIntegral
        : ton * fs * outputCapOnIntegral +
            toff * fs * outputCapOffIntegral +
            tidle * fs * outputCapMinOff * outputCapMinOff;
    final outputCapRms = math.sqrt(capOutRmsSquared);

    final duty = ton * fs;
    // Buck.java checkCurrentRipple() flags the ripple input when
    // !(iripple * 0.99 < Iout * rippleFraction). The original still
    // calculates and displays results, so preserve it as a warning.
    final warnings = <String>[];
    if (!(ripple * 0.99 < rippleTarget)) {
      warnings.add('Actual inductor ripple exceeds the requested ripple target.');
    }
    return CalculationResult(values: {
      'operatingInputVoltage': vin,
      'operatingLoadPercent': input.operatingLoadPercent,
      'operatingOutputCurrent': iout,
      'inputAverageCurrent': inputAverage,
      'inputPower': inputPower,
      'outputPower': outputPower,
      'diodeLosses': diodeLoss,
      'dutyCycle': duty,
      'minimumInductance': minimumInductance,
      'inductanceUsed': inductance,
      // TI PSD's iripple_buck is the CCM design-ripple estimate even in DCM.
      'designRippleCurrent': rippleCcm,
      // Physical excursion: peak-to-valley in CCM, zero-to-peak in DCM.
      'rippleCurrent': ripple,
      'ripplePercent': ripple / iout * 100.0,
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
    }, warnings: warnings);
  }
}
