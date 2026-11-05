class Units {
  const Units._();
  static double kiloToBase(double value) => value * 1e3;
  static double microToBase(double value) => value * 1e-6;
  static double baseToMicro(double value) => value * 1e6;
  static double baseToKilo(double value) => value / 1e3;
}
