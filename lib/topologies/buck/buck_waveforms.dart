import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'buck_inputs.dart';

/// One sample from the original PSD5 Buck graph time base (microseconds).
class BuckWaveformPoint {
  const BuckWaveformPoint(this.timeMicroseconds, this.value);
  final double timeMicroseconds;
  final double value;
}

class BuckDeviceMetrics {
  const BuckDeviceMetrics({
    required this.minimumVoltage,
    required this.maximumVoltage,
    required this.minimumCurrent,
    required this.maximumCurrent,
    required this.rmsCurrent,
    required this.averageCurrent,
    required this.acCurrent,
  });
  final double minimumVoltage;
  final double maximumVoltage;
  final double minimumCurrent;
  final double maximumCurrent;
  final double rmsCurrent;
  final double averageCurrent;
  final double acCurrent;

  // Graph.java chooses mV/mA from the complete side-label values, not from
  // an arbitrary single waveform sample.
  double get voltageScale =>
      minimumVoltage.abs() < 1 && maximumVoltage.abs() < 1 ? 1000 : 1;
  double get currentScale => [
    minimumCurrent, maximumCurrent, rmsCurrent, averageCurrent, acCurrent,
  ].every((value) => value.abs() < 1) ? 1000 : 1;
}

class BuckDeviceWaveform {
  const BuckDeviceWaveform({
    required this.id,
    required this.title,
    required this.voltage,
    required this.current,
    required this.metrics,
  });
  final String id;
  final String title;
  final List<BuckWaveformPoint> voltage;
  final List<BuckWaveformPoint> current;
  final BuckDeviceMetrics metrics;
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
    final ton = values['onTime']!;
    final toff = values['offTime']!;
    final tidle = values['idleTime']!;
    // Buck.java time_scale_raw uses t1+t2+t3, not 1/fs. In CCM t3=1 ns,
    // so its graph time base is one nanosecond longer than the nominal period.
    final cycleDuration = ton + toff + tidle;
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
      ton + toff - edge, ton + toff + edge, cycleDuration - edge,
      cycleDuration + edge, cycleDuration + ton - edge, cycleDuration + ton + edge,
      cycleDuration + ton + toff - edge, cycleDuration + ton + toff + edge,
      2 * cycleDuration - edge, 2 * cycleDuration + edge,
      2 * cycleDuration + ton - edge, 2 * cycleDuration + ton + edge,
      2 * cycleDuration + ton + toff - edge, 2 * cycleDuration + ton + toff + edge,
      3 * cycleDuration - edge, 3 * cycleDuration + edge, 3 * cycleDuration + ton - edge,
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
      // Graph.java's constructor and setPoints() discard the final array
      // element, so the original GUI actually plots the first 20 of 21.
      return List.unmodifiable(List.generate(
        20,
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

    double acCurrent(double rms, double average, {bool clampBelowAverage = false}) {
      if (clampBelowAverage && rms < average) return 0;
      return math.sqrt(rms * rms - average * average);
    }

    BuckDeviceMetrics metrics({
      required double minV, required double maxV,
      required double minI, required double maxI,
      required double rmsI, required double averageI,
      bool clampAc = false,
    }) => BuckDeviceMetrics(
      minimumVoltage: minV, maximumVoltage: maxV,
      minimumCurrent: minI, maximumCurrent: maxI,
      rmsCurrent: rmsI, averageCurrent: averageI,
      acCurrent: acCurrent(rmsI, averageI, clampBelowAverage: clampAc),
    );

    final inputCapMetrics = metrics(
      minV: values['inputCapacitorVoltageMin']!,
      maxV: values['inputCapacitorVoltageMax']!,
      minI: iin - peak,
      maxI: fetAverage,
      rmsI: values['inputCapacitorRmsCurrent']!,
      averageI: values['inputCapacitorAverageCurrent']!,
    );
    final fetMetrics = metrics(
      minV: values['mosfetVoltageMin']!, maxV: values['mosfetVoltageMax']!,
      minI: minimum, maxI: peak,
      rmsI: values['mosfetRmsCurrent']!, averageI: values['mosfetAverageCurrent']!,
    );
    final inductorMetrics = metrics(
      minV: values['inductorVoltageMin']!, maxV: values['inductorVoltageMax']!,
      minI: minimum, maxI: peak,
      rmsI: values['inductorRmsCurrent']!, averageI: values['inductorAverageCurrent']!,
      clampAc: true,
    );
    final diodeMetrics = metrics(
      minV: values['diodeVoltageMin']!, maxV: values['diodeVoltageMax']!,
      minI: minimum, maxI: peak,
      rmsI: values['diodeRmsCurrent']!, averageI: values['diodeAverageCurrent']!,
    );
    final outputCapMetrics = metrics(
      minV: values['outputCapacitorVoltageMin']!,
      maxV: values['outputCapacitorVoltageMax']!,
      minI: -iout, maxI: peak - iout,
      rmsI: values['outputCapacitorRmsCurrent']!,
      averageI: values['outputCapacitorAverageCurrent']!,
    );

    return BuckWaveformSet(List.unmodifiable([
      BuckDeviceWaveform(
        id: 'inputCapacitor', title: 'Input capacitor Ci',
        voltage: trace(List.filled(7, vin)), current: trace(inputCapCurrent),
        metrics: inputCapMetrics,
      ),
      BuckDeviceWaveform(
        id: 'mosfet', title: 'MOSFET Q1',
        voltage: trace(fetVoltage), current: trace(fetCurrent),
        metrics: fetMetrics,
      ),
      BuckDeviceWaveform(
        id: 'inductor', title: 'Inductor L1',
        voltage: trace(inductorVoltage), current: trace(inductorCurrent),
        metrics: inductorMetrics,
      ),
      BuckDeviceWaveform(
        id: 'diode', title: 'Freewheel diode D1',
        voltage: trace(diodeVoltage), current: trace(diodeCurrent),
        metrics: diodeMetrics,
      ),
      BuckDeviceWaveform(
        id: 'outputCapacitor', title: 'Output capacitor Co',
        voltage: trace(List.filled(7, vo)), current: trace(outputCapCurrent),
        metrics: outputCapMetrics,
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
    required this.metricLabels,
  });
  final BuckWaveformSet waveforms;
  final String voltageLabel;
  final String currentLabel;
  final String periodLabel;
  final Map<String, String> deviceTitles;
  final Map<String, String> metricLabels;

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
                    unit: 'V', scale: device.metrics.voltageScale,
                    color: theme.colorScheme.tertiary),
                  const SizedBox(height: 4),
                  _BuckTrace(points: device.current, label: currentLabel,
                    unit: 'A', scale: device.metrics.currentScale,
                    color: theme.colorScheme.primary),
                  const SizedBox(height: 6),
                  _BuckDeviceMetricsView(metrics: device.metrics, labels: metricLabels),
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
    required this.points, required this.label, required this.unit,
    required this.scale, required this.color,
  });
  final List<BuckWaveformPoint> points;
  final String label;
  final String unit;
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final displayUnit = scale == 1000.0 ? 'm$unit' : unit;
    return SizedBox(
    height: 76,
    child: Row(children: [
      SizedBox(width: 76, child: Text('$label ($displayUnit)',
        style: Theme.of(context).textTheme.labelSmall)),
      Expanded(child: CustomPaint(
        painter: _BuckTracePainter(points: points, scale: scale, color: color,
          gridColor: Theme.of(context).colorScheme.outlineVariant,
          textColor: Theme.of(context).colorScheme.onSurfaceVariant),
        child: const SizedBox.expand(),
      )),
    ]),
  );
  }
}

class _BuckDeviceMetricsView extends StatelessWidget {
  const _BuckDeviceMetricsView({required this.metrics, required this.labels});
  final BuckDeviceMetrics metrics;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final voltageScale = metrics.voltageScale;
    final currentScale = metrics.currentScale;
    final voltageUnit = voltageScale == 1000 ? 'mV' : 'V';
    final currentUnit = currentScale == 1000 ? 'mA' : 'A';
    final entries = <(String, String)>[
      ('minimumVoltage', '${(metrics.minimumVoltage * voltageScale).toStringAsFixed(2)} $voltageUnit'),
      ('maximumVoltage', '${(metrics.maximumVoltage * voltageScale).toStringAsFixed(2)} $voltageUnit'),
      ('minimumCurrent', '${(metrics.minimumCurrent * currentScale).toStringAsFixed(2)} $currentUnit'),
      ('maximumCurrent', '${(metrics.maximumCurrent * currentScale).toStringAsFixed(2)} $currentUnit'),
      ('rmsCurrent', '${(metrics.rmsCurrent * currentScale).toStringAsFixed(2)} $currentUnit'),
      ('averageCurrent', '${(metrics.averageCurrent * currentScale).toStringAsFixed(2)} $currentUnit'),
      ('acCurrent', '${(metrics.acCurrent * currentScale).toStringAsFixed(2)} $currentUnit'),
    ];
    final style = Theme.of(context).textTheme.labelSmall;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final entry in entries)
          Text('${labels[entry.$1] ?? entry.$1}: ${entry.$2}', style: style),
      ],
    );
  }
}

class _BuckTracePainter extends CustomPainter {
  const _BuckTracePainter({
    required this.points, required this.scale, required this.color,
    required this.gridColor, required this.textColor,
  });
  final List<BuckWaveformPoint> points;
  final double scale;
  final Color color;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 0 || size.height <= 0) return;
    const padX = 5.0, padY = 8.0;
    final vals = points.map((p) => p.value * scale);
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
    final path = Path()..moveTo(
      x(points.first.timeMicroseconds), y(points.first.value * scale));
    for (final p in points.skip(1)) {
      path.lineTo(x(p.timeMicroseconds), y(p.value * scale));
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
    old.points != points || old.scale != scale || old.color != color ||
    old.gridColor != gridColor || old.textColor != textColor;
}
