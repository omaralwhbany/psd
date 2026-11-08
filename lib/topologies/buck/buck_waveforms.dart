import 'package:flutter/material.dart';

import 'buck_inputs.dart';

/// One sample from the original PSD5 Buck graph time base (microseconds).
class BuckWaveformPoint {
  const BuckWaveformPoint(this.timeMicroseconds, this.value);
  final double timeMicroseconds;
  final double value;
}

class BuckDeviceWaveform {
  const BuckDeviceWaveform({
    required this.id,
    required this.title,
    required this.voltage,
    required this.current,
  });
  final String id;
  final String title;
  final List<BuckWaveformPoint> voltage;
  final List<BuckWaveformPoint> current;
}

/// Source-derived reconstruction of Buck.java's five paint* graph methods.
class BuckWaveformSet {
  const BuckWaveformSet(this.devices);
  final List<BuckDeviceWaveform> devices;

  factory BuckWaveformSet.fromCalculation({
    required BuckInputs input,
    required Map<String, double> values,
  }) {
    final vin = values['operatingInputVoltage']!;
    final vo = input.outputVoltage;
    final vf = input.diodeForwardVoltage;
    final period = 1 / input.switchingFrequency;
    final ton = values['onTime']!;
    final toff = values['offTime']!;
    final minimum = values['minimumCurrent']!;
    final peak = values['peakCurrent']!;
    final iout = input.outputCurrent;
    final iin = values['inputAverageCurrent']!;
    final fetAverage = values['mosfetAverageCurrent']!;
    final dcm = values['isCcm'] == 0;
    const edge = 1e-9;

    // Exact 21-point time_scale_raw sequence in Buck.java lines 437-457.
    final times = <double>[
      0.0, edge, ton - edge, ton + edge,
      ton + toff - edge, ton + toff + edge, period - edge,
      period + edge, period + ton - edge, period + ton + edge,
      period + ton + toff - edge, period + ton + toff + edge,
      2 * period - edge, 2 * period + edge,
      2 * period + ton - edge, 2 * period + ton + edge,
      2 * period + ton + toff - edge, 2 * period + ton + toff + edge,
      3 * period - edge, 3 * period + edge, 3 * period + ton - edge,
    ];

    List<BuckWaveformPoint> trace(List<double> samples) {
      if (samples.length != 7) {
        throw ArgumentError('A Buck.java trace requires seven transition values.');
      }
      // Java's overlapping 21-point sequence:
      // A,A,B,C,D,E,F,A,B,C,D,E,F,A,B,C,D,E,F,A,B.
      final sampleValues = <double>[
        ...samples,
        samples[0], samples[2], samples[3], samples[4], samples[5], samples[6], samples[0],
        samples[2], samples[3], samples[4], samples[5], samples[6], samples[0], samples[2],
      ];
      return List.unmodifiable(List.generate(
        21,
        (i) => BuckWaveformPoint(times[i] * 1e6, sampleValues[i]),
      ));
    }

    final fetVoltage = dcm
        ? [0.0, 0.0, 0.0, vin + vf, vin + vf, vin - vo, vin - vo]
        : [0.0, 0.0, 0.0, vin + vf, vin + vf, vin + vf, vin + vf];
    final fetCurrent = dcm
        ? [0.0, 0.0, peak, 0.0, 0.0, 0.0, 0.0]
        : [minimum, minimum, peak, 0.0, 0.0, 0.0, 0.0];

    final inductorVoltage = dcm
        ? [vin - vo, vin - vo, vin - vo, -vo - vf, -vo - vf, 0.0, 0.0]
        : [vin - vo, vin - vo, vin - vo, -vo - vf, -vo - vf, -vo - vf, -vo - vf];
    final inductorCurrent = dcm
        ? [0.0, 0.0, peak, peak, 0.0, 0.0, 0.0]
        : [minimum, minimum, peak, peak, minimum, minimum, minimum];

    final diodeVoltage = dcm
        ? [-vin, -vin, -vin, vf, vf, -vo, -vo]
        : [-vin, -vin, -vin, vf, vf, vf, vf];
    final diodeCurrent = dcm
        ? [0.0, 0.0, 0.0, peak, 0.0, 0.0, 0.0]
        : [0.0, 0.0, 0.0, peak, minimum, minimum, minimum];

    final inputCapCurrent = dcm
        ? [iin, iin, iin - peak, fetAverage, fetAverage, fetAverage, fetAverage]
        : [iin - minimum, iin - minimum, iin - peak, fetAverage, fetAverage, fetAverage, fetAverage];
    final outputCapCurrent = dcm
        ? [-iout, -iout, peak - iout, peak - iout, -iout, -iout, -iout]
        : [minimum - iout, minimum - iout, peak - iout, peak - iout,
            minimum - iout, minimum - iout, minimum - iout];

    return BuckWaveformSet(List.unmodifiable([
      BuckDeviceWaveform(
        id: 'inputCapacitor', title: 'Input capacitor Ci',
        voltage: trace(List.filled(7, vin)), current: trace(inputCapCurrent),
      ),
      BuckDeviceWaveform(
        id: 'mosfet', title: 'MOSFET Q1',
        voltage: trace(fetVoltage), current: trace(fetCurrent),
      ),
      BuckDeviceWaveform(
        id: 'inductor', title: 'Inductor L1',
        voltage: trace(inductorVoltage), current: trace(inductorCurrent),
      ),
      BuckDeviceWaveform(
        id: 'diode', title: 'Freewheel diode D1',
        voltage: trace(diodeVoltage), current: trace(diodeCurrent),
      ),
      BuckDeviceWaveform(
        id: 'outputCapacitor', title: 'Output capacitor Co',
        voltage: trace(List.filled(7, vo)), current: trace(outputCapCurrent),
      ),
    ]));
  }
}

class BuckDeviceWaveformsView extends StatelessWidget {
  const BuckDeviceWaveformsView({
    super.key,
    required this.waveforms,
    required this.voltageLabel,
    required this.currentLabel,
    required this.periodLabel,
    required this.deviceTitles,
  });
  final BuckWaveformSet waveforms;
  final String voltageLabel;
  final String currentLabel;
  final String periodLabel;
  final Map<String, String> deviceTitles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final device in waveforms.devices)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deviceTitles[device.id] ?? device.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _BuckTrace(points: device.voltage, label: voltageLabel,
                    unit: 'V', color: theme.colorScheme.tertiary),
                  const SizedBox(height: 4),
                  _BuckTrace(points: device.current, label: currentLabel,
                    unit: 'A', color: theme.colorScheme.primary),
                  const SizedBox(height: 2),
                  Text(periodLabel, style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BuckTrace extends StatelessWidget {
  const _BuckTrace({
    required this.points, required this.label, required this.unit, required this.color,
  });
  final List<BuckWaveformPoint> points;
  final String label;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 76,
    child: Row(children: [
      SizedBox(width: 76, child: Text('$label ($unit)',
        style: Theme.of(context).textTheme.labelSmall)),
      Expanded(child: CustomPaint(
        painter: _BuckTracePainter(points: points, color: color,
          gridColor: Theme.of(context).colorScheme.outlineVariant,
          textColor: Theme.of(context).colorScheme.onSurfaceVariant),
        child: const SizedBox.expand(),
      )),
    ]),
  );
}

class _BuckTracePainter extends CustomPainter {
  const _BuckTracePainter({
    required this.points, required this.color,
    required this.gridColor, required this.textColor,
  });
  final List<BuckWaveformPoint> points;
  final Color color;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 0 || size.height <= 0) return;
    const padX = 5.0, padY = 8.0;
    final vals = points.map((p) => p.value);
    var minV = vals.reduce((a, b) => a < b ? a : b);
    var maxV = vals.reduce((a, b) => a > b ? a : b);
    if ((maxV - minV).abs() < 1e-9) {
      final margin = maxV.abs() * 0.1 + 0.1;
      minV -= margin;
      maxV += margin;
    }
    final minT = points.first.timeMicroseconds;
    final maxT = points.last.timeMicroseconds;
    final spanT = (maxT - minT).abs() < 1e-12 ? 1.0 : maxT - minT;
    final spanV = maxV - minV;
    double x(double t) => padX + (t - minT) / spanT * (size.width - padX * 2);
    double y(double v) => size.height - padY -
      (v - minV) / spanV * (size.height - padY * 2);

    final grid = Paint()..color = gridColor..strokeWidth = 0.6;
    for (var i = 0; i <= 2; i++) {
      final yy = padY + (size.height - padY * 2) * i / 2;
      canvas.drawLine(Offset(padX, yy), Offset(size.width - padX, yy), grid);
    }
    final path = Path()..moveTo(x(points.first.timeMicroseconds), y(points.first.value));
    for (final p in points.skip(1)) {
      path.lineTo(x(p.timeMicroseconds), y(p.value));
    }
    canvas.drawPath(path, Paint()
      ..color = color..strokeWidth = 1.8
      ..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);

    final style = TextStyle(color: textColor, fontSize: 9);
    for (final item in [
      (minV, size.height - padY - 3),
      (maxV, padY),
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: item.$1.toStringAsFixed(2), style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      painter.paint(canvas, Offset(padX + 2, item.$2 - painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BuckTracePainter old) =>
    old.points != points || old.color != color ||
    old.gridColor != gridColor || old.textColor != textColor;
}
