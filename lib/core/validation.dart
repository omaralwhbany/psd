class Validation {
  const Validation._();
  static List<String> positiveValues(Map<String, double> values) {
    final errors = <String>[];
    values.forEach((name, value) {
      if (!value.isFinite || value <= 0) errors.add('$name must be a finite value greater than zero.');
    });
    return errors;
  }
}
