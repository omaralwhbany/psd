/// Special-value rendering used by the Buck result and waveform labels.
///
/// The original PSD5 DecimalFormat patterns render infinities as the infinity
/// symbol and NaN as "NaN". Finite values deliberately keep the existing
/// Flutter precision/rounding until the full DecimalFormat conversion is
/// independently reproduced.
extension TiDisplayNumber on double {
  String toTiDisplayStringAsFixed(int fractionDigits) {
    if (isNaN) return 'NaN';
    if (isInfinite) return isNegative ? '-∞' : '∞';
    return toStringAsFixed(fractionDigits);
  }
}
