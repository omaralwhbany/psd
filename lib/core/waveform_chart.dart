import 'package:flutter/material.dart';

/// Synchronized ideal steady-state waveforms for Buck and Boost converters.
/// This is an explanatory averaged-switching model, not a SPICE simulation.
class PowerWaveformChart extends StatelessWidget {
  const PowerWaveformChart({
    super.key,
    required this.averageCurrent,
    required this.rippleCurrent,
    required this.dutyCycle,
    required this.currentLabel,
    required this.switchHighDuringOn,
    this.discontinuous = false,
    this.onFraction,
    this.offFraction,
    this.idleFraction = 0,
    this.topology = 'buck',
    this.inputVoltage = 12,
    this.outputVoltage = 5,
    this.diodeDrop = 0,
    this.periodCaption = 'One switching period • D = ',
    this.idealizedNote = 'Idealized waveforms; parasitic effects, dead time and switching transitions are omitted.',
  });

  final double averageCurrent, rippleCurrent, dutyCycle;
  final String currentLabel;
  final bool switchHighDuringOn, discontinuous;
  final double? onFraction, offFraction;
  final double idleFraction;
  final String topology;
  final double inputVoltage, outputVoltage, diodeDrop;
  final String periodCaption, idealizedNote;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(currentLabel, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      SizedBox(
        height: 260,
        width: double.infinity,
        child: CustomPaint(painter: _SynchronizedWaveformPainter(
          averageCurrent: averageCurrent,
          rippleCurrent: rippleCurrent,
          dutyCycle: dutyCycle.clamp(0.001, 0.999),
          onFraction: (onFraction ?? dutyCycle).clamp(0.0, 1.0),
          offFraction: (offFraction ?? (1 - dutyCycle)).clamp(0.0, 1.0),
          discontinuous: discontinuous,
          topology: topology,
          vin: inputVoltage,
          vout: outputVoltage,
          diodeDrop: diodeDrop,
          currentColor: colors.primary,
          voltageColor: colors.tertiary,
          switchColor: colors.secondary,
          gateColor: colors.error,
          gridColor: colors.outlineVariant,
          textColor: colors.onSurfaceVariant,
        )),
      ),
      const SizedBox(height: 4),
      Text('$periodCaption${(dutyCycle * 100).toStringAsFixed(1)}% • ${discontinuous ? 'DCM' : 'CCM'}',
        style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(idealizedNote,
        style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _SynchronizedWaveformPainter extends CustomPainter {
  _SynchronizedWaveformPainter({
    required this.averageCurrent, required this.rippleCurrent,
    required this.dutyCycle, required this.onFraction, required this.offFraction,
    required this.discontinuous, required this.topology, required this.vin,
    required this.vout, required this.diodeDrop, required this.currentColor,
    required this.voltageColor, required this.switchColor, required this.gateColor,
    required this.gridColor, required this.textColor,
  });

  final double averageCurrent, rippleCurrent, dutyCycle, onFraction, offFraction;
  final bool discontinuous;
  final String topology;
  final double vin, vout, diodeDrop;
  final Color currentColor, voltageColor, switchColor, gateColor, gridColor, textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 86.0, right = 8.0, top = 5.0, bottom = 20.0, gap = 7.0;
    final plotLeft = left, plotRight = size.width - right;
    final plotWidth = (plotRight - plotLeft).clamp(1.0, double.infinity);
    final laneHeight = (size.height - top - bottom - gap * 3) / 4;
    final xOn = plotLeft + plotWidth * onFraction;
    final xOff = plotLeft + plotWidth * (onFraction + offFraction).clamp(0.0, 1.0);
    final isBuck = topology == 'buck';

    final currentLow = discontinuous ? 0.0 : averageCurrent - rippleCurrent / 2;
    final currentHigh = discontinuous ? rippleCurrent : averageCurrent + rippleCurrent / 2;
    // PSD5 Buck.java sets inductor voltage to Vin - Vo during the ON interval;
    // the diode drop applies only to the freewheel OFF interval.
    final vlOn = isBuck ? vin - vout : vin;
    final vlOff = isBuck ? -(vout + diodeDrop) : vin - (vout + diodeDrop);
    // For Buck, PSD5 Buck.java models the MOSFET voltage as:
    // 0 V while ON, Vin + Vf while the diode freewheels, and Vin - Vo
    // during the DCM zero-inductor-current interval.
    final vSwitchOn = 0.0;
    final vSwitchOff = isBuck ? vin + diodeDrop : vout + diodeDrop;
    final switchIdle = isBuck ? vin - vout : vout;
    final vlValues = [vlOn, vlOff, 0.0];
    final switchValues = discontinuous
        ? [vSwitchOn, vSwitchOff, switchIdle]
        : [vSwitchOn, vSwitchOff];
    double minOf(List<double> values) => values.reduce((a, b) => a < b ? a : b);
    double maxOf(List<double> values) => values.reduce((a, b) => a > b ? a : b);
    final vlMin = minOf(vlValues);
    final vlMax = maxOf(vlValues);
    final swMin = minOf(switchValues);
    final swMax = maxOf(switchValues);
    final labels = ['IL (A)', 'VL (V)', 'VSW (V)', 'GATE'];
    final colors = [currentColor, voltageColor, switchColor, gateColor];
    final grid = Paint()..color = gridColor..strokeWidth = 0.7;
    final style = TextStyle(color: textColor, fontSize: 10);

    for (var lane = 0; lane < 4; lane++) {
      final yTop = top + lane * (laneHeight + gap);
      final yBottom = yTop + laneHeight;
      final label = TextPainter(text: TextSpan(text: labels[lane], style: style),
        textDirection: TextDirection.ltr)..layout(maxWidth: left - 5);
      label.paint(canvas, Offset(2, yTop));
      final axisMin = lane == 0 ? currentLow : lane == 1 ? vlMin : lane == 2 ? swMin : 0.0;
      final axisMax = lane == 0 ? currentHigh : lane == 1 ? vlMax : lane == 2 ? swMax : 1.0;
      for (var i = 0; i <= 2; i++) {
        final y = yTop + laneHeight * i / 2;
        canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), grid);
        final value = axisMax - (axisMax - axisMin) * i / 2;
        final tick = TextPainter(
          text: TextSpan(text: value.toStringAsFixed(value.abs() >= 100 ? 0 : 1), style: style.copyWith(fontSize: 9)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 34);
        tick.paint(canvas, Offset(plotLeft - tick.width - 5, y - tick.height / 2));
      }
      canvas.drawLine(Offset(plotLeft, yBottom), Offset(plotRight, yBottom), grid);

      double yFor(double value, double min, double max) {
        final span = (max - min).abs() < 1e-9 ? 1.0 : max - min;
        return yBottom - ((value - min) / span) * (laneHeight * 0.78) - laneHeight * 0.11;
      }

      final path = Path();
      if (lane == 0) {
        path.moveTo(plotLeft, yFor(discontinuous ? 0 : currentLow, currentLow, currentHigh));
        path.lineTo(xOn, yFor(currentHigh, currentLow, currentHigh));
        path.lineTo(xOff, yFor(discontinuous ? 0 : currentLow, currentLow, currentHigh));
        path.lineTo(plotRight, yFor(discontinuous ? 0 : currentLow, currentLow, currentHigh));
      } else if (lane == 1) {
        path.moveTo(plotLeft, yFor(vlOn, vlMin, vlMax));
        path.lineTo(xOn, yFor(vlOn, vlMin, vlMax));
        path.lineTo(xOn, yFor(vlOff, vlMin, vlMax));
        path.lineTo(xOff, yFor(vlOff, vlMin, vlMax));
        if (discontinuous) {
          path.lineTo(xOff, yFor(0, vlMin, vlMax));
          path.lineTo(plotRight, yFor(0, vlMin, vlMax));
        }
      } else if (lane == 2) {
        path.moveTo(plotLeft, yFor(vSwitchOn, swMin, swMax));
        path.lineTo(xOn, yFor(vSwitchOn, swMin, swMax));
        path.lineTo(xOn, yFor(vSwitchOff, swMin, swMax));
        path.lineTo(xOff, yFor(vSwitchOff, swMin, swMax));
        if (discontinuous) {
          path.lineTo(xOff, yFor(switchIdle, swMin, swMax));
          path.lineTo(plotRight, yFor(switchIdle, swMin, swMax));
        }
      } else {
        path.moveTo(plotLeft, yFor(1, 0, 1));
        path.lineTo(xOn, yFor(1, 0, 1));
        path.lineTo(xOn, yFor(0, 0, 1));
        path.lineTo(plotRight, yFor(0, 0, 1));
      }
      canvas.drawPath(path, Paint()..color = colors[lane]..strokeWidth = 2.1
        ..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);
    }

    final timeStyle = TextStyle(color: textColor, fontSize: 9);
    void timeLabel(String text, double x) {
      final p = TextPainter(text: TextSpan(text: text, style: timeStyle),
        textDirection: TextDirection.ltr)..layout();
      p.paint(canvas, Offset((x - p.width / 2).clamp(plotLeft, plotRight - p.width), size.height - 12));
    }
    timeLabel('0', plotLeft);
    timeLabel('D·T', xOn);
    timeLabel('T', plotRight);
  }

  @override
  bool shouldRepaint(covariant _SynchronizedWaveformPainter old) =>
      old.averageCurrent != averageCurrent || old.rippleCurrent != rippleCurrent ||
      old.dutyCycle != dutyCycle || old.onFraction != onFraction ||
      old.offFraction != offFraction || old.discontinuous != discontinuous ||
      old.topology != topology || old.vin != vin || old.vout != vout ||
      old.diodeDrop != diodeDrop || old.currentColor != currentColor ||
      old.voltageColor != voltageColor || old.switchColor != switchColor ||
      old.gateColor != gateColor || old.gridColor != gridColor;
}
