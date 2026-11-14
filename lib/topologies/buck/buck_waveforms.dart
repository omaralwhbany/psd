import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'buck_inputs.dart';

/// Formats a finite binary64 value with Java DecimalFormat's default
/// HALF_EVEN rounding. The PSD5 graph first rounds labels to six fractional
/// places, parses them back to double, and only then applies its unit choice.
String _formatJavaDecimal(
  double value, {
  required int minFractionDigits,
  required int maxFractionDigits,
}) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';

  final data = ByteData(8)..setFloat64(0, value, Endian.big);
  final bits = data.getInt64(0, Endian.big);
  final exponentBits = (bits >> 52) & 0x7ff;
  final fractionBits = bits & 0x000fffffffffffff;
  final mantissa =
      exponentBits == 0 ? fractionBits : fractionBits | (1 << 52);
  final binaryExponent =
      exponentBits == 0 ? -1074 : exponentBits - 1023 - 52;
  final decimalScale = BigInt.from(10).pow(maxFractionDigits);
  final numerator = BigInt.from(mantissa) * decimalScale;

  late final BigInt rounded;
  if (binaryExponent >= 0) {
    rounded = numerator << binaryExponent;
  } else {
    final denominator = BigInt.one << -binaryExponent;
    final quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator);
    final twiceRemainder = remainder << 1;
    final comparison = twiceRemainder.compareTo(denominator);
    final roundUp =
        comparison > 0 || (comparison == 0 && quotient.isOdd);
    rounded = roundUp ? quotient + BigInt.one : quotient;
  }

  final integerPart = rounded ~/ decimalScale;
  var fractionalPart =
      (rounded % decimalScale).toString().padLeft(maxFractionDigits, '0');
  while (fractionalPart.length > minFractionDigits &&
      fractionalPart.endsWith('0')) {
    fractionalPart =
        fractionalPart.substring(0, fractionalPart.length - 1);
  }
  return '${bits.isNegative ? '-' : ''}$integerPart.$fractionalPart';
}

double _javaGraphLabelValue(double value) {
  if (!value.isFinite) return value;
  return double.parse(
    _formatJavaDecimal(
      value,
      minFractionDigits: 2,
      maxFractionDigits: 6,
    ),
  );
}

/// Graph.java compares the parsed, six-decimal Buck label strings to 1.0.
/// Negating >= preserves its original NaN behavior.
bool _javaGraphLabelKeepsMilliPrefix(double value) =>
    !(_javaGraphLabelValue(value).abs() >= 1.0);

/// Graph.java formats the already-rounded source label after unit conversion.
String _formatJavaGraphMetric(double value, double scale) =>
    _formatJavaDecimal(
      _javaGraphLabelValue(value) * scale,
      minFractionDigits: 2,
      maxFractionDigits: 2,
    );

/// One sample from the original PSD5 Buck graph time base (microseconds).
class BuckWaveformPoint {
  const BuckWaveformPoint(this.timeMicroseconds, this.value);
  final double timeMicroseconds;
  final double value;
}

/// The x-axis bounds used by the original GraphPanel across all plotted points.
class BuckGraphTimeRange {
  const BuckGraphTimeRange({
    required this.minimumMicroseconds,
    required this.maximumMicroseconds,
  });

  final double minimumMicroseconds;
  final double maximumMicroseconds;

  double get spanMicroseconds => maximumMicroseconds - minimumMicroseconds;

  /// GraphPanel maps x directly from zero; it scales by the full range but
  /// deliberately does not subtract minimumMicroseconds from each sample.
  double graphPanelXOffset(double timeMicroseconds, double plotWidth) {
    final mappingX = plotWidth / spanMicroseconds.abs();
    return timeMicroseconds * mappingX;
  }

  /// Reproduces GraphPanel's DecimalFormat input for a tick label.
  double graphPanelTickLabelValue(
    double timeMicroseconds,
    double plotWidth,
  ) {
    final mappingX = plotWidth / spanMicroseconds.abs();
    return maximumMicroseconds * (timeMicroseconds * mappingX / plotWidth);
  }

  factory BuckGraphTimeRange.fromPoints(List<BuckWaveformPoint> points) {
    if (points.isEmpty) {
      throw ArgumentError(
          'A Buck graph time range requires at least one point.');
    }
    var minimum = points.first.timeMicroseconds;
    var maximum = minimum;
    for (final point in points.skip(1)) {
      if (point.timeMicroseconds < minimum) {
        minimum = point.timeMicroseconds;
      }
      if (point.timeMicroseconds > maximum) {
        maximum = point.timeMicroseconds;
      }
    }
    return BuckGraphTimeRange(
      minimumMicroseconds: minimum,
      maximumMicroseconds: maximum,
    );
  }
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

  // Buck.java formats side-label values with DecimalFormat("#0.00####")
  // before Graph.java checks whether their absolute value is at least 1.
  // Six fractional digits mean 0.9999995 rounds to 1.00, so it uses V/A.
  double get voltageScale =>
      [minimumVoltage, maximumVoltage].every(_javaGraphLabelKeepsMilliPrefix)
          ? 1000
          : 1;
  double get currentScale => [
        minimumCurrent,
        maximumCurrent,
        rmsCurrent,
        averageCurrent,
        acCurrent,
      ].every(_javaGraphLabelKeepsMilliPrefix)
          ? 1000
          : 1;
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
    final iout = values['operatingOutputCurrent']!;
    final iin = values['inputAverageCurrent']!;
    final fetAverage = values['mosfetAverageCurrent']!;
    final dcm = values['isCcm'] == 0;
    const edge = 1e-9;

    // Exact 21-point time_scale_raw sequence in Buck.java lines 437-457.
    final times = <double>[
      0.0,
      edge,
      ton - edge,
      ton + edge,
      ton + toff - edge,
      ton + toff + edge,
      cycleDuration - edge,
      cycleDuration + edge,
      cycleDuration + ton - edge,
      cycleDuration + ton + edge,
      cycleDuration + ton + toff - edge,
      cycleDuration + ton + toff + edge,
      2 * cycleDuration - edge,
      2 * cycleDuration + edge,
      2 * cycleDuration + ton - edge,
      2 * cycleDuration + ton + edge,
      2 * cycleDuration + ton + toff - edge,
      2 * cycleDuration + ton + toff + edge,
      3 * cycleDuration - edge,
      3 * cycleDuration + edge,
      3 * cycleDuration + ton - edge,
    ];

    List<BuckWaveformPoint> trace(List<double> samples) {
      if (samples.length != 7) {
        throw ArgumentError(
            'A Buck.java trace requires seven transition values.');
      }
      // Java's overlapping 21-point sequence:
      // A,A,B,C,D,E,F,A,B,C,D,E,F,A,B,C,D,E,F,A,B.
      final sampleValues = <double>[
        ...samples,
        samples[0],
        samples[2],
        samples[3],
        samples[4],
        samples[5],
        samples[6],
        samples[0],
        samples[2],
        samples[3],
        samples[4],
        samples[5],
        samples[6],
        samples[0],
        samples[2],
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
        : [
            vin - vo,
            vin - vo,
            vin - vo,
            -vo - vf,
            -vo - vf,
            -vo - vf,
            -vo - vf
          ];
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
        : [
            iin - minimum,
            iin - minimum,
            iin - peak,
            fetAverage,
            fetAverage,
            fetAverage,
            fetAverage
          ];
    final outputCapCurrent = dcm
        ? [-iout, -iout, peak - iout, peak - iout, -iout, -iout, -iout]
        : [
            minimum - iout,
            minimum - iout,
            peak - iout,
            peak - iout,
            minimum - iout,
            minimum - iout,
            minimum - iout
          ];

    double acCurrent(double rms, double average,
        {bool clampBelowAverage = false}) {
      if (clampBelowAverage && rms < average) return 0;
      return math.sqrt(rms * rms - average * average);
    }

    BuckDeviceMetrics metrics({
      required double minV,
      required double maxV,
      required double minI,
      required double maxI,
      required double rmsI,
      required double averageI,
      bool clampAc = false,
    }) =>
        BuckDeviceMetrics(
          minimumVoltage: minV,
          maximumVoltage: maxV,
          minimumCurrent: minI,
          maximumCurrent: maxI,
          rmsCurrent: rmsI,
          averageCurrent: averageI,
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
      minV: values['mosfetVoltageMin']!,
      maxV: values['mosfetVoltageMax']!,
      minI: minimum,
      maxI: peak,
      rmsI: values['mosfetRmsCurrent']!,
      averageI: values['mosfetAverageCurrent']!,
    );
    final inductorMetrics = metrics(
      minV: values['inductorVoltageMin']!,
      maxV: values['inductorVoltageMax']!,
      minI: minimum,
      maxI: peak,
      rmsI: values['inductorRmsCurrent']!,
      averageI: values['inductorAverageCurrent']!,
      clampAc: true,
    );
    final diodeMetrics = metrics(
      minV: values['diodeVoltageMin']!,
      maxV: values['diodeVoltageMax']!,
      minI: minimum,
      maxI: peak,
      rmsI: values['diodeRmsCurrent']!,
      averageI: values['diodeAverageCurrent']!,
    );
    final outputCapMetrics = metrics(
      minV: values['outputCapacitorVoltageMin']!,
      maxV: values['outputCapacitorVoltageMax']!,
      minI: dcm ? -iout : minimum - iout,
      maxI: peak - iout,
      rmsI: values['outputCapacitorRmsCurrent']!,
      averageI: values['outputCapacitorAverageCurrent']!,
    );

    return BuckWaveformSet(List.unmodifiable([
      BuckDeviceWaveform(
        id: 'inputCapacitor',
        title: 'Input capacitor Ci',
        voltage: trace(List.filled(7, vin)),
        current: trace(inputCapCurrent),
        metrics: inputCapMetrics,
      ),
      BuckDeviceWaveform(
        id: 'mosfet',
        title: 'MOSFET Q1',
        voltage: trace(fetVoltage),
        current: trace(fetCurrent),
        metrics: fetMetrics,
      ),
      BuckDeviceWaveform(
        id: 'inductor',
        title: 'Inductor L1',
        voltage: trace(inductorVoltage),
        current: trace(inductorCurrent),
        metrics: inductorMetrics,
      ),
      BuckDeviceWaveform(
        id: 'diode',
        title: 'Freewheel diode D1',
        voltage: trace(diodeVoltage),
        current: trace(diodeCurrent),
        metrics: diodeMetrics,
      ),
      BuckDeviceWaveform(
        id: 'outputCapacitor',
        title: 'Output capacitor Co',
        voltage: trace(List.filled(7, vo)),
        current: trace(outputCapCurrent),
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
    required this.timeAxisLabel,
    required this.deviceTitles,
    required this.metricLabels,
  });
  final BuckWaveformSet waveforms;
  final String voltageLabel;
  final String currentLabel;
  final String periodLabel;
  final String timeAxisLabel;
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
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _BuckTrace(
                      points: device.voltage,
                      label: voltageLabel,
                      unit: 'V',
                      timeAxisLabel: timeAxisLabel,
                      scale: device.metrics.voltageScale,
                      color: theme.colorScheme.tertiary),
                  const SizedBox(height: 4),
                  _BuckTrace(
                      points: device.current,
                      label: currentLabel,
                      unit: 'A',
                      timeAxisLabel: timeAxisLabel,
                      scale: device.metrics.currentScale,
                      color: theme.colorScheme.primary),
                  const SizedBox(height: 6),
                  _BuckDeviceMetricsView(
                      metrics: device.metrics, labels: metricLabels),
                  const SizedBox(height: 2),
                  Text(periodLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
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
    required this.points,
    required this.label,
    required this.unit,
    required this.timeAxisLabel,
    required this.scale,
    required this.color,
  });
  final List<BuckWaveformPoint> points;
  final String label;
  final String unit;
  final String timeAxisLabel;
  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final displayUnit = scale == 1000.0 ? 'm$unit' : unit;
    return SizedBox(
      height: 94,
      child: Row(textDirection: TextDirection.ltr, children: [
        SizedBox(
            width: 96,
            child: Directionality(
              textDirection: Directionality.of(context),
              child: Text('$label ($displayUnit)',
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            )),
        Expanded(
            child: Column(children: [
          Expanded(
              child: CustomPaint(
            painter: _BuckTracePainter(
                points: points,
                scale: scale,
                color: color,
                gridColor: Theme.of(context).colorScheme.outlineVariant,
                textColor: Theme.of(context).colorScheme.onSurfaceVariant),
            child: const SizedBox.expand(),
          )),
          Text(timeAxisLabel, style: Theme.of(context).textTheme.labelSmall),
        ])),
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
      (
        'minimumVoltage',
        '${_formatJavaGraphMetric(metrics.minimumVoltage, voltageScale)} $voltageUnit'
      ),
      (
        'maximumVoltage',
        '${_formatJavaGraphMetric(metrics.maximumVoltage, voltageScale)} $voltageUnit'
      ),
      (
        'minimumCurrent',
        '${_formatJavaGraphMetric(metrics.minimumCurrent, currentScale)} $currentUnit'
      ),
      (
        'maximumCurrent',
        '${_formatJavaGraphMetric(metrics.maximumCurrent, currentScale)} $currentUnit'
      ),
      (
        'rmsCurrent',
        '${_formatJavaGraphMetric(metrics.rmsCurrent, currentScale)} $currentUnit'
      ),
      (
        'averageCurrent',
        '${_formatJavaGraphMetric(metrics.averageCurrent, currentScale)} $currentUnit'
      ),
      (
        'acCurrent',
        '${_formatJavaGraphMetric(metrics.acCurrent, currentScale)} $currentUnit'
      ),
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
    required this.points,
    required this.scale,
    required this.color,
    required this.gridColor,
    required this.textColor,
  });
  final List<BuckWaveformPoint> points;
  final double scale;
  final Color color;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 0 || size.height <= 0) return;
    const left = 31.0, right = 5.0, top = 7.0, bottom = 19.0;
    final plotRight = size.width - right;
    final plotBottom = size.height - bottom;
    if (plotRight <= left || plotBottom <= top) return;

    final values = points.map((point) => point.value * scale);
    var minValue = values.reduce((a, b) => a < b ? a : b);
    var maxValue = values.reduce((a, b) => a > b ? a : b);
    if (minValue > 0) minValue = 0;
    if (maxValue < 0) maxValue = 0;
    final valueSpan = maxValue - minValue;
    // GraphPanel scans every retained point for both x-axis extrema. The
    // fixed 1 ns edge offsets can make early samples negative when ton < 1 ns.
    final timeRange = BuckGraphTimeRange.fromPoints(points);
    final timeMax = timeRange.maximumMicroseconds;
    final timeSpan = timeRange.spanMicroseconds;
    if (timeSpan <= 0) return;

    double x(double time) =>
        left + timeRange.graphPanelXOffset(time, plotRight - left);
    double y(double value) => valueSpan == 0
        ? plotBottom
        : plotBottom - (value - minValue) / valueSpan * (plotBottom - top);
    final zeroY = y(0);

    final axis = Paint()
      ..color = gridColor
      ..strokeWidth = 0.7;
    canvas.drawLine(const Offset(left, top), Offset(left, plotBottom), axis);
    canvas.drawLine(Offset(left, zeroY), Offset(plotRight, zeroY), axis);

    final textStyle = TextStyle(color: textColor, fontSize: 8);
    void drawRightAligned(String text, double baselineY) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 5);
      painter.paint(canvas,
          Offset(left - painter.width - 4, baselineY - painter.height / 2));
    }

    final middleValue = maxValue / 2;
    final middleY = (zeroY + top) / 2;
    drawRightAligned(
      _formatJavaDecimal(
        maxValue,
        minFractionDigits: 2,
        maxFractionDigits: 2,
      ),
      top,
    );
    drawRightAligned(
      _formatJavaDecimal(
        middleValue,
        minFractionDigits: 2,
        maxFractionDigits: 2,
      ),
      middleY,
    );
    drawRightAligned(
      _formatJavaDecimal(
        minValue,
        minFractionDigits: 2,
        maxFractionDigits: 2,
      ),
      plotBottom,
    );
    canvas.drawLine(Offset(left - 4, middleY), Offset(left + 4, middleY), axis);

    var lastLabelRight = -1000.0;
    for (final index in [0, 6, 12, 18]) {
      if (index >= points.length) continue;
      final px = x(points[index].timeMicroseconds);
      canvas.drawLine(Offset(px, zeroY - 4), Offset(px, zeroY + 4), axis);
      final painter = TextPainter(
        text: TextSpan(
            text: _formatJavaDecimal(
              timeRange.graphPanelTickLabelValue(
                points[index].timeMicroseconds,
                plotRight - left,
              ),
              minFractionDigits: 2,
              maxFractionDigits: 2,
            ),
            style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final start = px - painter.width / 2;
      if (start < lastLabelRight) continue;
      painter.paint(canvas, Offset(start, zeroY + 5));
      lastLabelRight = start + 30;
    }
    final maxPainter = TextPainter(
      text: TextSpan(
        text: _formatJavaDecimal(
          timeMax,
          minFractionDigits: 2,
          maxFractionDigits: 2,
        ),
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final maxStart = plotRight - maxPainter.width / 2;
    if (maxStart >= lastLabelRight) {
      maxPainter.paint(canvas, Offset(maxStart, zeroY + 5));
    }

    final path = Path()
      ..moveTo(x(points.first.timeMicroseconds), y(points.first.value * scale));
    for (final point in points.skip(1)) {
      path.lineTo(x(point.timeMicroseconds), y(point.value * scale));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _BuckTracePainter old) =>
      old.points != points ||
      old.scale != scale ||
      old.color != color ||
      old.gridColor != gridColor ||
      old.textColor != textColor;
}
