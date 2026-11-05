class BuckInputs {
  const BuckInputs({
    required this.inputVoltageMin,
    required this.inputVoltageMax,
    required this.outputVoltage,
    required this.outputCurrent,
    required this.switchingFrequency,
    required this.rippleFraction,
    required this.diodeForwardVoltage,
    this.operatingInputVoltage,
    this.selectedInductance,
  });

  final double inputVoltageMin;
  final double inputVoltageMax;
  final double outputVoltage;
  final double outputCurrent;
  final double switchingFrequency;
  final double rippleFraction;
  final double diodeForwardVoltage;
  final double? operatingInputVoltage;
  final double? selectedInductance;

  factory BuckInputs.defaults() => const BuckInputs(
    inputVoltageMin: 18,
    inputVoltageMax: 36,
    outputVoltage: 12,
    outputCurrent: 5,
    switchingFrequency: 200e3,
    rippleFraction: 0.30,
    diodeForwardVoltage: 0.5,
  );
}