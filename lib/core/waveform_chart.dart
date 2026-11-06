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
  });

  final double averageCurrent, rippleCurrent, dutyCycle;
  final String currentLabel;
  final bool switchHighDuringOn, discontinuous;
  final double? onFraction, offFraction;
  final double idleFraction;
  final String topology;
  final double inputVoltage, outputVoltage, diodeDrop;

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
      Text('One switching period • D = ${(dutyCycle * 100).toStringAsFixed(1)}% • ${discontinuous ? 'DCM' : 'CCM'}',
        style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text('Idealized waveforms; parasitic effects, dead time and switching transitions are omitted.',
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
    const left = 62.0, right = 8.0, top = 5.0, bottom = 20.0, gap = 7.0;
    final plotLeft = left, plotRight = size.width - right;
    final plotWidth = (plotRight - plotLeft).clamp(1.0, double.infinity);
    final laneHeight = (size.height - top - bottom - gap * 3) / 4;
    final xOn = plotLeft + plotWidth * onFraction;
    final xOff = plotLeft + plotWidth * (onFraction + offFraction).clamp(0.0, 1.0);
    final isBuck = topology == 'buck';

    final currentLow = discontinuous ? 0.0 : averageCurrent - rippleCurrent / 2;
    final currentHigh = discontinuous ? rippleCurrent : averageCurrent + rippleCurrent / 2;
    final vlOn = isBuck ? vin - vout - diodeDrop : vin;
    final vlOff = isBuck ? -(vout + diodeDrop) : vin - vout;
    final vSwitchOn = isBuck ? vin : 0.0;
    final vSwitchOff = isBuck ? -diodeDrop : vout;
    final voltageValues = [vlOn, vlOff, 0.0, vSwitchOn, vSwitchOff];
    final vMin = voltageValues.reduce((a, b) => a < b ? a : b);
    final vMax = voltageValues.reduce((a, b) => a > b ? a : b);
    final labels = ['IL (A)', 'VL (V)', 'VSW (V)', 'GATE'];
    final colors = [currentColor, voltageColor, switchColor, gateColor];
    final grid = Paint()..color = gridColor..strokeWidth = 0.7;
    final style = TextStyle(color: textColor, fontSize: 10);

    for (var lane = 0; lane < 4; lane++) {
      final yTop = top + lane * (laneHeight + gap);
      final yBottom = yTop + laneHeight;
      final label = TextPainter(text: TextSpan(text: labels[lane], style: style),
        textDirection: TextDirection.ltr)..layout(maxWidth: left - 5);
      label.paint(canvas, Offset(2, (yTop + yBottom - label.height) / 2));
      for (var i = 0; i <= 2; i++) {
        final y = yTop + laneHeight * i / 2;
        canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), grid);
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
        path.lineTo(plotRight, yFor(0, currentLow, currentHigh));
      } else if (lane == 1) {
        path.moveTo(plotLeft, yFor(vlOn, vMin, vMax));
        path.lineTo(xOn, yFor(vlOn, vMin, vMax));
        path.lineTo(xOn, yFor(vlOff, vMin, vMax));
        path.lineTo(xOff, yFor(vlOff, vMin, vMax));
        if (discontinuous) {
          path.lineTo(xOff, yFor(0, vMin, vMax));
          path.lineTo(plotRight, yFor(0, vMin, vMax));
        } else {
          path.lineTo(plotRight, yFor(vlOn, vMin, vMax));
        }
      } else if (lane == 2) {
        path.moveTo(plotLeft, yFor(vSwitchOn, vMin, vMax));
        path.lineTo(xOn, yFor(vSwitchOn, vMin, vMax));
        path.lineTo(xOn, yFor(vSwitchOff, vMin, vMax));
        path.lineTo(plotRight, yFor(vSwitchOff, vMin, vMax));
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
