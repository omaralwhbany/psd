import 'package:flutter/material.dart';
import '../../core/units.dart';
import '../../core/waveform_chart.dart';
import '../../localization/app_strings.dart';
import 'boost_engine.dart';
import 'boost_inputs.dart';

class BoostScreen extends StatefulWidget {
  const BoostScreen({super.key});
  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen> {
  final _controllers = <String, TextEditingController>{};
  bool _customInductance = false;
  final _engine = const BoostEngine();

  @override
  void initState() {
    super.initState();
    final d = BoostInputs.defaults();
    _controllers.addAll({
      'vinMin': TextEditingController(text: d.inputVoltageMin.toString()),
      'vinMax': TextEditingController(text: d.inputVoltageMax.toString()),
      'vinOperating': TextEditingController(text: d.inputVoltageMin.toString()),
      'vout': TextEditingController(text: d.outputVoltage.toString()),
      'iout': TextEditingController(text: d.outputCurrent.toString()),
      'fsw': TextEditingController(text: Units.baseToKilo(d.switchingFrequency).toStringAsFixed(0)),
      'ripple': TextEditingController(text: (d.rippleFraction * 100).toStringAsFixed(0)),
      'vf': TextEditingController(text: d.diodeForwardVoltage.toString()),
      'inductance': TextEditingController(text: '100'),
    });
  }

  @override
  void dispose() { for (final c in _controllers.values) { c.dispose(); } super.dispose(); }

  double _v(String key) => double.tryParse(_controllers[key]!.text.trim()) ?? double.nan;
  BoostInputs get _input => BoostInputs(
    inputVoltageMin: _v('vinMin'), inputVoltageMax: _v('vinMax'),
    outputVoltage: _v('vout'), outputCurrent: _v('iout'),
    switchingFrequency: Units.kiloToBase(_v('fsw')), rippleFraction: _v('ripple') / 100,
    operatingInputVoltage: _v('vinOperating'), diodeForwardVoltage: _v('vf'),
    selectedInductance: _customInductance ? Units.microToBase(_v('inductance')) : null,
  );

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(Localizations.localeOf(context));
    final input = _input;
    final r = _engine.calculate(input);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
      Text(s.boostConverter, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('Non-isolated • Step-up DC-DC converter'),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.inputs, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
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
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => setState(() {}),
          icon: const Icon(Icons.calculate), label: Text(s.results))),
      ]))),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.results, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        if (r.isValid) ...[
          _result(s.dutyCycle, '${(r.values['dutyCycle']! * 100).toStringAsFixed(2)} %'),
          _result(s.minimumInductance, '${Units.baseToMicro(r.values['minimumInductance']!).toStringAsFixed(2)} µH'),
          _result(s.inductanceUsed, '${Units.baseToMicro(r.values['inductanceUsed']!).toStringAsFixed(2)} µH'),
          _result(s.inputCurrent, '${r.values['inputAverageCurrent']!.toStringAsFixed(3)} A'),
          _result(s.rippleCurrent, '${r.values['rippleCurrent']!.toStringAsFixed(3)} A'),
          _result(s.peakCurrent, '${r.values['peakCurrent']!.toStringAsFixed(3)} A'),
          _result(s.minimumCurrent, '${r.values['minimumCurrent']!.toStringAsFixed(3)} A'),
          _result('Critical design input voltage', '${r.values['designInputVoltage']!.toStringAsFixed(2)} V'),
          _result(s.operatingMode, r.values['isCcm'] == 1 ? s.ccm : s.dcm),
        ] else ...r.errors.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6),
          child: Text(e, style: const TextStyle(color: Colors.red)))),
        if (r.isValid) ...[
          const SizedBox(height: 14),
          PowerWaveformChart(
            averageCurrent: r.values['inputAverageCurrent']!,
            rippleCurrent: r.values['rippleCurrent']!,
            dutyCycle: r.values['dutyCycle']!,
            currentLabel: r.values['isCcm'] == 0 ? 'Boost inductor current (DCM)' : 'Boost inductor current (CCM)',
            switchHighDuringOn: false,
            discontinuous: r.values['isCcm'] == 0,
            onFraction: r.values['onFraction']!,
            offFraction: r.values['offFraction']!,
            idleFraction: r.values['idleFraction']!,
            topology: 'boost',
            inputVoltage: r.values['operatingInputVoltage']!,
            outputVoltage: input.outputVoltage,
            diodeDrop: input.diodeForwardVoltage,
          ),
        ],
      ]))),
    ]);
  }

  Widget _field(String label, String key, String unit) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LayoutBuilder(builder: (context, constraints) {
      final input = TextField(controller: _controllers[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.end, decoration: InputDecoration(suffixText: unit, isDense: true),
        onChanged: (_) => setState(() {}));
      if (constraints.maxWidth < 380) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(label), const SizedBox(height: 5), input]);
      }
      return Row(children: [Expanded(flex: 5, child: Text(label)), const SizedBox(width: 12),
        Expanded(flex: 4, child: input)]);
    }),
  );

  Widget _result(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );
}
