class BuckInputs {
  const BuckInputs({required this.inputVoltageMin, required this.inputVoltageMax, required this.outputVoltage, required this.outputCurrent, required this.switchingFrequency, required this.rippleFraction, required this.diodeForwardVoltage, required this.inductance});
  final double inputVoltageMin;
  final double inputVoltageMax;
  final double outputVoltage;
  final double outputCurrent;
  final double switchingFrequency;
  final double rippleFraction;
  final double diodeForwardVoltage;
  final double inductance;
  factory BuckInputs.defaults() => const BuckInputs(inputVoltageMin: 18, inputVoltageMax: 36, outputVoltage: 12, outputCurrent: 5, switchingFrequency: 200e3, rippleFraction: 0.30, diodeForwardVoltage: 0.5, inductance: 33e-6);
}
