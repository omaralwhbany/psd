/// Special-value rendering used by Buck result and waveform labels.
///
/// PSD5 DecimalFormat renders infinities as the infinity symbol and NaN as
/// "NaN". Finite values keep the existing Flutter precision/rounding until
/// the full DecimalFormat conversion is independently reproduced.
extension TiDisplayNumber on double {
  String toTiFixed(int fractionDigits) {
    if (isNaN) return 'NaN';
    if (isInfinite) return isNegative ? '-∞' : '∞';
    return toStringAsFixed(fractionDigits);
  }
}
