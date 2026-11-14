import 'package:flutter/material.dart';
import '../../core/units.dart';
import '../../core/waveform_chart.dart';
import 'buck_waveforms.dart';
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
  double _operatingLoadPercent = 100;

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

  // Buck.java displays ON/OFF times in ns below 100 ns, otherwise in µs.
  String _formatTiTime(double seconds) => seconds < 1e-7
      ? '${(seconds * 1e9).toStringAsFixed(2)} ns'
      : '${Units.baseToMicro(seconds).toStringAsFixed(2)} µs';

  // DecimalFormat("#0.00") in PSD5 displays positive infinity as U+221E.
  String _formatTiInductance(double henries) {
    if (henries.isInfinite) {
      return '${henries.isNegative ? '-' : ''}∞ µH';
    }
    return '${Units.baseToMicro(henries).toStringAsFixed(2)} µH';
  }

  BuckInputs get _input => BuckInputs(
    inputVoltageMin: _v('vinMin'), inputVoltageMax: _v('vinMax'),
    outputVoltage: _v('vout'), outputCurrent: _v('iout'),
    switchingFrequency: Units.kiloToBase(_v('fsw')),
    rippleFraction: _v('ripple') / 100, diodeForwardVoltage: _v('vf'),
    operatingInputVoltage: _v('vinOperating'),
    operatingLoadPercent: _operatingLoadPercent,
    selectedInductance: _customInductance ? Units.microToBase(_v('inductance')) : null,
  );

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(Localizations.localeOf(context));
    final input = _input;
    final result = _engine.calculate(input);
    final onTimeWarning = result.warnings.contains(BuckEngine.psdOnTimeWarning);
    final offTimeWarning = result.warnings.contains(BuckEngine.psdOffTimeWarning);
    final inductanceWarning = onTimeWarning || offTimeWarning;
    final inputRangeWarning = input.outputVoltage > input.inputVoltageMin;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
      Text(s.buckConverter, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(s.buckDescription, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
      const SizedBox(height: 16),
      _panel(s.schematic, const BuckSchematic()),
      const SizedBox(height: 14),
      _panel(s.inputs, Column(children: [
        _field(s.inputVoltageMin, 'vinMin', 'V', warning: inputRangeWarning),
        _field(s.inputVoltageMax, 'vinMax', 'V'),
        _field(s.operatingInputVoltage, 'vinOperating', 'V'),
        _field(s.outputVoltage, 'vout', 'V', warning: inputRangeWarning),
        _field(s.outputCurrent, 'iout', 'A'),
        _field(s.switchingFrequency, 'fsw', 'kHz'),
        _field(s.ripplePercent, 'ripple', '%'),
        _field(s.diodeDrop, 'vf', 'V'),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(s.loadLevel)),
            Text('${_operatingLoadPercent.toStringAsFixed(0)} %'),
          ]),
          Slider(
            value: _operatingLoadPercent,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_operatingLoadPercent.toStringAsFixed(0)} %',
            onChanged: (value) => setState(() => _operatingLoadPercent = value),
          ),
          Text(s.loadControlNote, style: Theme.of(context).textTheme.bodySmall),
        ]),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(s.customInductor),
          subtitle: Text(s.automaticInductor), value: _customInductance,
          onChanged: (v) => setState(() => _customInductance = v)),
        if (_customInductance)
          _field(s.inductance, 'inductance', 'µH', warning: inductanceWarning),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: () => setState(() {}), icon: const Icon(Icons.calculate), label: Text(s.results))),
      ])),
      const SizedBox(height: 14),
      _panel(s.results, result.isValid ? Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final warning in result.warnings)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.localizeBuckWarning(warning),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onTertiaryContainer))),
                ],
              ),
            ),
          _sectionTitle(s.operatingPoint),
          _result(s.operatingMode, result.values['isCcm'] == 1 ? s.ccm : s.dcm, emphasize: true),
          _result(s.operatingOutputCurrent, '${result.values['operatingOutputCurrent']!.toStringAsFixed(3)} A'),
          _result(s.dutyCycle, '${(result.values['dutyCycle']! * 100).toStringAsFixed(2)} %'),
          _result(s.switchingPeriod, '${Units.baseToMicro(1 / input.switchingFrequency).toStringAsFixed(2)} µs',
            warning: onTimeWarning),
          _result(s.onTime, _formatTiTime(result.values['onTime']!),
            warning: onTimeWarning),
          _result(s.offTime, _formatTiTime(result.values['offTime']!),
            warning: offTimeWarning),
          _result(s.zeroCurrentTime, '${Units.baseToMicro(result.values['idleTime']!).toStringAsFixed(2)} µs'),
          const Divider(height: 22),
          _sectionTitle(s.inductor),
          _result(
            s.minimumInductance,
            _formatTiInductance(result.values['minimumInductance']!),
          ),
          _result(s.inductanceUsed, '${Units.baseToMicro(result.values['inductanceUsed']!).toStringAsFixed(2)} µH',
            warning: inductanceWarning),
          if (result.values['isCcm'] == 0)
            _result(s.designRippleCurrent, '${result.values['designRippleCurrent']!.toStringAsFixed(3)} A'),
          _result(result.values['isCcm'] == 0 ? s.actualCurrentExcursion : s.rippleCurrent,
            '${result.values['rippleCurrent']!.toStringAsFixed(3)} A'),
          _result(s.actualRipplePercent, '${result.values['ripplePercent']!.toStringAsFixed(2)} %'),
          _result(s.graphAverageCurrent, '${result.values['inductorAverageCurrent']!.toStringAsFixed(3)} A'),
          _result(s.graphRmsCurrent, '${result.values['inductorRmsCurrent']!.toStringAsFixed(3)} A'),
          _result(s.peakCurrent, '${result.values['inductorPeakCurrent']!.toStringAsFixed(3)} A'),
          _result(s.graphMinimumCurrent, '${result.values['minimumCurrent']!.toStringAsFixed(3)} A'),
          _result(s.voltageMinMax, '${result.values['inductorVoltageMin']!.toStringAsFixed(2)} / ${result.values['inductorVoltageMax']!.toStringAsFixed(2)} V'),
          const Divider(height: 22),
          _sectionTitle(s.mosfet),
          _result(s.graphAverageCurrent, '${result.values['mosfetAverageCurrent']!.toStringAsFixed(3)} A'),
          _result(s.graphRmsCurrent, '${result.values['mosfetRmsCurrent']!.toStringAsFixed(3)} A'),
          _result(s.peakCurrentGeneric, '${result.values['mosfetPeakCurrent']!.toStringAsFixed(3)} A'),
          _result(s.voltageMinMax, '${result.values['mosfetVoltageMin']!.toStringAsFixed(2)} / ${result.values['mosfetVoltageMax']!.toStringAsFixed(2)} V'),
          _result(s.voltageAtZeroCurrent, '${result.values['mosfetVoltageAtZeroCurrent']!.toStringAsFixed(2)} V'),
          const Divider(height: 22),
          _sectionTitle(s.freewheelDiode),
          _result(s.graphAverageCurrent, '${result.values['diodeAverageCurrent']!.toStringAsFixed(3)} A'),
          _result(s.graphRmsCurrent, '${result.values['diodeRmsCurrent']!.toStringAsFixed(3)} A'),
          _result(s.peakCurrentGeneric, '${result.values['diodePeakCurrent']!.toStringAsFixed(3)} A'),
          _result(s.voltageMinMax, '${result.values['diodeVoltageMin']!.toStringAsFixed(2)} / ${result.values['diodeVoltageMax']!.toStringAsFixed(2)} V'),
          _result(s.voltageAtZeroCurrent, '${result.values['diodeVoltageAtZeroCurrent']!.toStringAsFixed(2)} V'),
          const Divider(height: 22),
          _sectionTitle(s.capacitors),
          _result(s.inputCapacitorRmsCurrent, '${result.values['inputCapacitorRmsCurrent']!.toStringAsFixed(3)} A'),
          _result(s.inputCapacitorVoltage, '${result.values['inputCapacitorVoltageMin']!.toStringAsFixed(2)} V'),
          _result(s.outputCapacitorRmsCurrent, '${result.values['outputCapacitorRmsCurrent']!.toStringAsFixed(3)} A'),
          _result(s.outputCapacitorVoltage, '${result.values['outputCapacitorVoltageMin']!.toStringAsFixed(2)} V'),
          const Divider(height: 22),
          _sectionTitle(s.power),
          _result(s.outputPower, '${result.values['outputPower']!.toStringAsFixed(2)} W'),
          _result(s.diodeLoss, '${result.values['diodeLosses']!.toStringAsFixed(2)} W'),
          _result(s.inputPower, '${result.values['inputPower']!.toStringAsFixed(2)} W'),
          _result(s.inputCurrent, '${result.values['inputAverageCurrent']!.toStringAsFixed(3)} A'),
        ],
      ) : _errors(result.errors, result.warnings, s)),
      if (result.isValid) ...[
        const SizedBox(height: 14),
        _panel(s.deviceWaveforms, BuckDeviceWaveformsView(
          waveforms: BuckWaveformSet.fromCalculation(input: input, values: result.values),
          voltageLabel: s.voltage,
          currentLabel: s.current,
          periodLabel: s.threeSwitchingPeriods,
          timeAxisLabel: s.timeScale,
          deviceTitles: {
            'inputCapacitor': s.inputCapacitor,
            'mosfet': s.mosfet,
            'inductor': s.inductor,
            'diode': s.freewheelDiode,
            'outputCapacitor': s.outputCapacitor,
          },
          metricLabels: {
            'minimumVoltage': s.graphMinimumVoltage,
            'maximumVoltage': s.graphMaximumVoltage,
            'minimumCurrent': s.graphMinimumCurrent,
            'maximumCurrent': s.graphMaximumCurrent,
            'rmsCurrent': s.graphRmsCurrent,
            'averageCurrent': s.graphAverageCurrent,
            'acCurrent': s.graphAcCurrent,
          },
        )),
        const SizedBox(height: 14),
        _panel(s.synchronizedWaveforms, PowerWaveformChart(
          averageCurrent: result.values['operatingOutputCurrent']!,
          rippleCurrent: result.values['rippleCurrent']!,
          dutyCycle: result.values['dutyCycle']!,
          currentLabel: result.values['isCcm'] == 0 ? s.buckDcmCurrent : s.buckCcmCurrent,
          switchHighDuringOn: true,
          discontinuous: result.values['isCcm'] == 0,
          onFraction: result.values['onFraction']!,
          offFraction: result.values['offFraction']!,
          idleFraction: result.values['idleFraction']!,
          topology: 'buck',
          inputVoltage: result.values['operatingInputVoltage']!,
          outputVoltage: input.outputVoltage,
          diodeDrop: input.diodeForwardVoltage,
          periodCaption: s.oneSwitchingPeriod,
          idealizedNote: s.idealizedWaveformNote,
        )),
      ],
    ]);
  }

  Widget _errors(List<String> errors, List<String> warnings, AppStrings strings) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final warning in warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              strings.localizeBuckWarning(warning),
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          ),
        for (final error in errors)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              strings.localizeBuckError(error),
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ]);

  Widget _field(String label, String key, String unit, {bool warning = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LayoutBuilder(builder: (context, constraints) {
          final theme = Theme.of(context);
          final input = TextField(
            controller: _controllers[key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.end,
            style: warning
                ? TextStyle(color: theme.colorScheme.onError)
                : null,
            decoration: InputDecoration(
              suffixText: unit,
              isDense: true,
              filled: warning,
              fillColor: warning ? theme.colorScheme.error : null,
              suffixStyle: warning
                  ? TextStyle(color: theme.colorScheme.onError)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          );
          if (constraints.maxWidth < 380) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Text(label), const SizedBox(height: 5), input],
            );
          }
          return Row(children: [
            Expanded(flex: 5, child: Text(label)),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: input),
          ]);
        }),
      );

  Widget _panel(String title, Widget child) => Card(child: Padding(padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 12), child,
    ])));

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 6),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
  );

  Widget _result(
    String label,
    String value, {
    bool emphasize = false,
    bool warning = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(builder: (context, constraints) {
          final colors = Theme.of(context).colorScheme;
          final valueText = Text(
            value,
            textAlign: TextAlign.end,
            softWrap: true,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: warning
                  ? colors.error
                  : emphasize
                      ? colors.primary
                      : null,
            ),
          );
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label),
                const SizedBox(height: 3),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: valueText,
                ),
              ],
            );
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 5, child: Text(label, softWrap: true)),
            const SizedBox(width: 10),
            Expanded(flex: 4, child: valueText),
          ]);
        }),
      );
}
