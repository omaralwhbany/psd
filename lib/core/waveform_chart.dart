import 'package:flutter/material.dart';

/// Idealized steady-state inductor-current and switch-node waveforms.
/// These are explanatory waveforms, not a time-domain circuit simulation.
class PowerWaveformChart extends StatelessWidget {
  const PowerWaveformChart({
    super.key,
    required this.averageCurrent,
    required this.rippleCurrent,
    required this.dutyCycle,
    required this.currentLabel,
    required this.switchHighDuringOn,
  });

  final double averageCurrent;
  final double rippleCurrent;
  final double dutyCycle;
  final String currentLabel;
  final bool switchHighDuringOn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(currentLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        SizedBox(
          height: 150,
          width: double.infinity,
          child: CustomPaint(
            painter: _PowerWaveformPainter(
              averageCurrent: averageCurrent,
              rippleCurrent: rippleCurrent,
              dutyCycle: dutyCycle.clamp(0.01, 0.99),
              switchHighDuringOn: switchHighDuringOn,
              currentColor: colors.primary,
              switchColor: colors.tertiary,
              gridColor: colors.outlineVariant,
              textColor: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (context, constraints) {
          final legends = [
            _LegendDot(color: colors.primary, label: 'Inductor current'),
            _LegendDot(color: colors.tertiary, label: 'Switch-node voltage (normalized)'),
          ];
          if (constraints.maxWidth < 390) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: legends.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: item,
              )).toList(),
            );
          }
          return Wrap(spacing: 16, runSpacing: 6, children: legends);
        }),
        const SizedBox(height: 4),
        Text('Idealized one-cycle view • Duty: ${(dutyCycle * 100).toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Flexible(child: Text(label, softWrap: true, style: Theme.of(context).textTheme.bodySmall)),
    ],
  );
}

class _PowerWaveformPainter extends CustomPainter {
  _PowerWaveformPainter({
    required this.averageCurrent,
    required this.rippleCurrent,
    required this.dutyCycle,
    required this.switchHighDuringOn,
    required this.currentColor,
    required this.switchColor,
    required this.gridColor,
    required this.textColor,
  });

  final double averageCurrent;
  final double rippleCurrent;
  final double dutyCycle;
  final bool switchHighDuringOn;
  final Color currentColor;
  final Color switchColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 20.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final grid = Paint()..color = gridColor..strokeWidth = 0.7;
    final axis = Paint()..color = textColor..strokeWidth = 1;
    final current = Paint()..color = currentColor..strokeWidth = 2.4..style = PaintingStyle.stroke;
    final sw = Paint()..color = switchColor..strokeWidth = 2..style = PaintingStyle.stroke;

    for (var i = 0; i <= 4; i++) {
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
    canvas.drawLine(Offset(plot.left, plot.top), Offset(plot.left, plot.bottom), axis);
    canvas.drawLine(Offset(plot.left, plot.bottom), Offset(plot.right, plot.bottom), axis);

    final low = averageCurrent - rippleCurrent / 2;
    final high = averageCurrent + rippleCurrent / 2;
    final span = (high - low).abs().clamp(0.000001, double.infinity);
    final minY = low - span * 0.45;
    final maxY = high + span * 0.45;
    double yFor(double value) => plot.bottom - (value - minY) / (maxY - minY) * plot.height;
    final xMid = plot.left + plot.width * dutyCycle;

    final triangle = Path()
      ..moveTo(plot.left, yFor(low))
      ..lineTo(xMid, yFor(high))
      ..lineTo(plot.right, yFor(low));
    canvas.drawPath(triangle, current);

    final highY = plot.top + plot.height * 0.12;
    final lowY = plot.top + plot.height * 0.42;
    final onY = switchHighDuringOn ? highY : lowY;
    final offY = switchHighDuringOn ? lowY : highY;
    final switchPath = Path()
      ..moveTo(plot.left, onY)
      ..lineTo(xMid, onY)
      ..lineTo(xMid, offY)
      ..lineTo(plot.right, offY);
    canvas.drawPath(switchPath, sw);

    final textStyle = TextStyle(color: textColor, fontSize: 10);
    final labels = [
      TextPainter(text: TextSpan(text: '0', style: textStyle), textDirection: TextDirection.ltr)..layout(),
      TextPainter(text: TextSpan(text: 'D·T', style: textStyle), textDirection: TextDirection.ltr)..layout(),
      TextPainter(text: TextSpan(text: 'T', style: textStyle), textDirection: TextDirection.ltr)..layout(),
    ];
    labels[0].paint(canvas, Offset(plot.left - 3, plot.bottom + 4));
    labels[1].paint(canvas, Offset(xMid - labels[1].width / 2, plot.bottom + 4));
    labels[2].paint(canvas, Offset(plot.right - labels[2].width, plot.bottom + 4));
  }

  @override
  bool shouldRepaint(covariant _PowerWaveformPainter old) =>
      old.averageCurrent != averageCurrent ||
      old.rippleCurrent != rippleCurrent ||
      old.dutyCycle != dutyCycle ||
      old.switchHighDuringOn != switchHighDuringOn ||
      old.currentColor != currentColor ||
      old.switchColor != switchColor ||
      old.gridColor != gridColor;
}
