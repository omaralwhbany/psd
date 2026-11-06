import 'package:flutter/material.dart';
import '../../core/units.dart';
import '../../core/waveform_chart.dart';
import '../../localization/app_strings.dart';
import 'buck_engine.dart';
import 'buck_inputs.dart';
import 'buck_schematic.dart';

class BuckScreen extends StatefulWidget {
  const BuckScreen({super.key});
  @override
  State<BuckScreen> createState() => _BuckScreenState();
}

class _BuckScreenState extends State<BuckScreen> {
  final _controllers = <String, TextEditingController>{};
  final _engine = const BuckEngine();
  bool _customInductance = false;

  @override
  void initState() {
    super.initState();
    final d = BuckInputs.defaults();
    _controllers.addAll({
      'vinMin': TextEditingController(text: d.inputVoltageMin.toString()),
      'vinMax': TextEditingController(text: d.inputVoltageMax.toString()),
      'vinOperating': TextEditingController(text: d.inputVoltageMin.toString()),
      'vout': TextEditingController(text: d.outputVoltage.toString()),
      'iout': TextEditingController(text: d.outputCurrent.toString()),
      'fsw': TextEditingController(text: Units.baseToKilo(d.switchingFrequency).toStringAsFixed(0)),
      'ripple': TextEditingController(text: (d.rippleFraction * 100).toStringAsFixed(0)),
      'vf': TextEditingController(text: d.diodeForwardVoltage.toString()),
      'inductance': TextEditingController(text: '33'),
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  double _v(String key) => double.tryParse(_controllers[key]!.text.trim()) ?? double.nan;

  BuckInputs get _input => BuckInputs(
    inputVoltageMin: _v('vinMin'), inputVoltageMax: _v('vinMax'),
    outputVoltage: _v('vout'), outputCurrent: _v('iout'),
    switchingFrequency: Units.kiloToBase(_v('fsw')),
    rippleFraction: _v('ripple') / 100, diodeForwardVoltage: _v('vf'),
    operatingInputVoltage: _v('vinOperating'),
    selectedInductance: _customInductance ? Units.microToBase(_v('inductance')) : null,
  );

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(Localizations.localeOf(context));
    final input = _input;
    final result = _engine.calculate(input);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
      Text(s.buckConverter, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('Non-isolated • Step-down DC-DC converter', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
      const SizedBox(height: 16),
      _panel(s.schematic, const BuckSchematic()),
      const SizedBox(height: 14),
      _panel(s.inputs, Column(children: [
        _field(s.inputVoltageMin, 'vinMin', 'V'),
        _field(s.inputVoltageMax, 'vinMax', 'V'),
        _field('Operating input voltage', 'vinOperating', 'V'),
        _field(s.outputVoltage, 'vout', 'V'),
        _field(s.outputCurrent, 'iout', 'A'),
        _field(s.switchingFrequency, 'fsw', 'kHz'),
        _field(s.ripplePercent, 'ripple', '%'),
        _field(s.diodeDrop, 'vf', 'V'),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(s.customInductor),
          subtitle: Text(s.automaticInductor), value: _customInductance,
          onChanged: (v) => setState(() => _customInductance = v)),
        if (_customInductance) _field(s.inductance, 'inductance', 'µH'),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: () => setState(() {}), icon: const Icon(Icons.calculate), label: Text(s.results))),
      ])),
      const SizedBox(height: 14),
      _panel(s.results, result.isValid ? Column(children: [
        _result(s.dutyCycle, '${(result.values['dutyCycle']! * 100).toStringAsFixed(2)} %'),
        _result(s.minimumInductance, '${Units.baseToMicro(result.values['minimumInductance']!).toStringAsFixed(2)} µH'),
        _result(s.inductanceUsed, '${Units.baseToMicro(result.values['inductanceUsed']!).toStringAsFixed(2)} µH'),
        _result(s.rippleCurrent, '${result.values['rippleCurrent']!.toStringAsFixed(3)} A'),
        _result(s.peakCurrent, '${result.values['peakCurrent']!.toStringAsFixed(3)} A'),
        _result(s.minimumCurrent, '${result.values['minimumCurrent']!.toStringAsFixed(3)} A'),
        _result(s.operatingMode, result.values['isCcm'] == 1 ? s.ccm : s.dcm, emphasize: true),
      ]) : _errors(result.errors)),
      if (result.isValid) ...[
        const SizedBox(height: 14),
        _panel('Synchronized waveforms', PowerWaveformChart(
          averageCurrent: input.outputCurrent,
          rippleCurrent: result.values['rippleCurrent']!,
          dutyCycle: result.values['dutyCycle']!,
          currentLabel: result.values['isCcm'] == 0 ? 'Buck inductor current (DCM)' : 'Buck inductor current (CCM)',
          switchHighDuringOn: true,
          discontinuous: result.values['isCcm'] == 0,
          onFraction: result.values['onFraction']!,
          offFraction: result.values['offFraction']!,
          idleFraction: result.values['idleFraction']!,
          topology: 'buck',
          inputVoltage: result.values['operatingInputVoltage']!,
          outputVoltage: input.outputVoltage,
          diodeDrop: input.diodeForwardVoltage,
        )),
      ],
    ]);
  }

  Widget _errors(List<String> errors) => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: errors.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Text(e, style: const TextStyle(color: Colors.red)))).toList());

  Widget _field(String label, String key, String unit) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LayoutBuilder(builder: (context, constraints) {
      final input = TextField(controller: _controllers[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.end, decoration: InputDecoration(suffixText: unit, isDense: true),
        onChanged: (_) => setState(() {}));
      if (constraints.maxWidth < 380) return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(label), const SizedBox(height: 5), input]);
      return Row(children: [Expanded(flex: 5, child: Text(label)), const SizedBox(width: 12),
        Expanded(flex: 4, child: input)]);
    }),
  );

  Widget _panel(String title, Widget child) => Card(child: Padding(padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 12), child,
    ])));

  Widget _result(String label, String value, {bool emphasize = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [Expanded(child: Text(label)),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold,
        color: emphasize ? Theme.of(context).colorScheme.primary : null))]),
  );
}
