class BoostInputs {
  const BoostInputs({
    required this.inputVoltageMin,
    required this.inputVoltageMax,
    required this.outputVoltage,
    required this.outputCurrent,
    required this.switchingFrequency,
    required this.rippleFraction,
    this.diodeForwardVoltage = 0.7,
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

  factory BoostInputs.defaults() => const BoostInputs(
    inputVoltageMin: 9,
    inputVoltageMax: 16,
    outputVoltage: 24,
    outputCurrent: 2,
    switchingFrequency: 100e3,
    rippleFraction: 0.30,
    diodeForwardVoltage: 0.7,
  );
}
