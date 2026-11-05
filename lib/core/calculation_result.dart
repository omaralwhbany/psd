class CalculationResult {
  const CalculationResult({required this.values, this.warnings = const [], this.errors = const []});
  final Map<String, double> values;
  final List<String> warnings;
  final List<String> errors;
  bool get isValid => errors.isEmpty;
}
