import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'buck_inputs.dart';
import 'buck_java_decimal_format.dart';

/// Mirrors Buck.java's six-decimal side-label rounding and Graph.java's
/// negated >= 1 comparison. NaN therefore does not trigger the V/A prefix.
bool _javaGraphLabelKeepsMilliPrefix(double value) =>
    !(value.abs() >= 0.9999995);

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

  double _mappingX(double plotWidth) {
    // GraphPanel uses 100.0 for both a zero-only range and any equal bounds.
    if ((maximumMicroseconds == 0.0 && minimumMicroseconds == 0.0) ||
        maximumMicroseconds == minimumMicroseconds) {
      return 100.0;
    }
    return plotWidth / spanMicroseconds.abs();
  }

  /// GraphPanel maps x directly from zero; it scales by the full range but
  /// deliberately does not subtract minimumMicroseconds from each sample.
  double graphPanelXOffset(double timeMicroseconds, double plotWidth) {
    return timeMicroseconds * _mappingX(plotWidth);
  }

  /// Reproduces GraphPanel's DecimalFormat input for a tick label.
  double graphPanelTickLabelValue(
    double timeMicroseconds,
    double plotWidth,
  ) {
    final mappingX = _mappingX(plotWidth);
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

    // Buck.java evaluates later cycle starts as repeated left-associative
    // t1+t2+t3 additions. Multiplying cycleDuration by 2 or 3 changes a few ULPs.
    final secondCycleStart = cycleDuration + ton + toff + tidle;
    final thirdCycleStart = secondCycleStart + ton + toff + tidle;
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
      secondCycleStart - edge,
      secondCycleStart + edge,
      secondCycleStart + ton - edge,
      secondCycleStart + ton + edge,
      secondCycleStart + ton + toff - edge,
      secondCycleStart + ton + toff + edge,
      thirdCycleStart - edge,
      thirdCycleStart + edge,
      thirdCycleStart + ton - edge,
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
        '${(metrics.minimumVoltage * voltageScale).toStringAsFixed(2)} $voltageUnit'
      ),
      (
        'maximumVoltage',
        '${(metrics.maximumVoltage * voltageScale).toStringAsFixed(2)} $voltageUnit'
      ),
      (
        'minimumCurrent',
        '${(metrics.minimumCurrent * currentScale).toStringAsFixed(2)} $currentUnit'
      ),
      (
        'maximumCurrent',
        '${(metrics.maximumCurrent * currentScale).toStringAsFixed(2)} $currentUnit'
      ),
      (
        'rmsCurrent',
        '${(metrics.rmsCurrent * currentScale).toStringAsFixed(2)} $currentUnit'
      ),
      (
        'averageCurrent',
        '${(metrics.averageCurrent * currentScale).toStringAsFixed(2)} $currentUnit'
      ),
      (
        'acCurrent',
        '${(metrics.acCurrent * currentScale).toStringAsFixed(2)} $currentUnit'
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

/// Returns the original GraphPanel x coordinate only when its binary64
/// mapping becomes non-finite or overflows. For ordinary finite ranges the
/// painter keeps its smooth Flutter mapping. GraphPanel uses a 100.0 mapping
/// for equal x bounds and Java's d2i conversion for non-finite coordinates.
@visibleForTesting
double? buckJavaGraphPanelFallbackX({
  required double value,
  required double minimum,
  required double maximum,
  required double plotLeft,
  required double plotWidth,
}) {
  final span = maximum - minimum;
  final mappingX = ((maximum == 0.0 && minimum == 0.0) || maximum == minimum)
      ? 100.0
      : plotWidth / span.abs();
  final mappedValue = value * mappingX;
  final coordinate = plotLeft + mappedValue;

  if (value.isFinite &&
      minimum.isFinite &&
      maximum.isFinite &&
      span.isFinite &&
      mappingX.isFinite &&
      mappedValue.isFinite &&
      coordinate.isFinite &&
      coordinate >= -2147483648.0 &&
      coordinate <= 2147483647.0) {
    return null;
  }
  return _javaGraphPanelInt(coordinate).toDouble();
}

/// DecimalFormat("#0.00") renders Java's exceptional floating values using
/// the infinity symbol rather than Dart's "Infinity" spelling.
@visibleForTesting
String buckJavaGraphPanelAxisLabel(double value) {
  if (value.isNaN) return 'NaN';
  if (value == double.infinity) return '∞';
  if (value == double.negativeInfinity) return '-∞';
  return formatBuckJavaDecimal(
    value,
    minFractionDigits: 2,
    maxFractionDigits: 2,
  );
}

/// Returns the original GraphPanel y coordinate only when its binary64
/// mapping becomes non-finite or overflows. For ordinary finite ranges the
/// painter keeps its smooth Flutter mapping. Java2D narrows each non-finite
/// y coordinate to a signed 32-bit integer (NaN -> 0), rather than replacing
/// every point with zero when one graph bound is infinite.
@visibleForTesting
double? buckJavaGraphPanelFallbackY({
  required double value,
  required double minimum,
  required double maximum,
  required double plotTop,
  required double plotBottom,
}) {
  var minValue = minimum;
  var maxValue = maximum;
  if (minValue > 0) minValue = 0;
  if (maxValue < 0) maxValue = 0;

  final span = (maxValue - minValue).abs();
  late final double mappingY;
  if (maxValue == 0 && minValue == 0) {
    mappingY = 100.0;
  } else {
    mappingY = (plotBottom - plotTop) / span;
  }
  final mappedValue = value * mappingY;
  late final double down;
  if (minValue == 0) {
    down = plotBottom;
  } else if (maxValue == 0) {
    down = plotTop;
  } else {
    down = plotBottom + mappingY * minValue;
  }

  if (value.isFinite &&
      minValue.isFinite &&
      maxValue.isFinite &&
      span.isFinite &&
      mappingY.isFinite &&
      mappedValue.isFinite &&
      down.isFinite) {
    return null;
  }

  late final int javaDown;
  if (minValue == 0) {
    javaDown = _javaGraphPanelInt(plotBottom);
  } else if (maxValue == 0) {
    javaDown = _javaGraphPanelInt(plotTop);
  } else {
    javaDown = _javaGraphPanelInt(down);
  }
  return _javaGraphPanelInt(javaDown - mappedValue).toDouble();
}

int _javaGraphPanelInt(double value) {
  if (value.isNaN) return 0;
  if (value >= 2147483647.0) return 2147483647;
  if (value <= -2147483648.0) return -2147483648;
  return value.truncate();
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

    final values =
        points.map((point) => point.value * scale).toList(growable: false);
    // GraphPanel initializes each bound from the first sample and only
    // replaces it after a strict comparison. This preserves its NaN behavior:
    // a first NaN pins the bounds, while later NaN samples are ignored.
    var minValue = values.first;
    var maxValue = values.first;
    for (final value in values.skip(1)) {
      if (minValue > value) minValue = value;
      if (maxValue < value) maxValue = value;
    }
    if (minValue > 0) minValue = 0;
    if (maxValue < 0) maxValue = 0;
    final valueSpan = maxValue - minValue;
    // GraphPanel scans every retained point for both x-axis extrema. The
    // fixed 1 ns edge offsets can make early samples negative when ton < 1 ns.
    final timeRange = BuckGraphTimeRange.fromPoints(points);
    final timeMax = timeRange.maximumMicroseconds;

    double x(double time) {
      final fallback = buckJavaGraphPanelFallbackX(
        value: time,
        minimum: timeRange.minimumMicroseconds,
        maximum: timeRange.maximumMicroseconds,
        plotLeft: left,
        plotWidth: plotRight - left,
      );
      if (fallback != null) return fallback;
      final mapped = left + timeRange.graphPanelXOffset(time, plotRight - left);
      return mapped.isFinite ? mapped : 0;
    }

    double y(double value) {
      // GraphPanel uses height / abs(maxY - minY), then Java's d2i cast for
      // the baseline and every plotted y coordinate. Preserve those fallback
      // coordinates when a finite input creates an infinite range or when a
      // waveform contains NaN/Infinity.
      final fallback = buckJavaGraphPanelFallbackY(
        value: value,
        minimum: minValue,
        maximum: maxValue,
        plotTop: top,
        plotBottom: plotBottom,
      );
      if (fallback != null) return fallback;
      return valueSpan == 0
          ? plotBottom
          : plotBottom - (value - minValue) / valueSpan * (plotBottom - top);
    }

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
    drawRightAligned(buckJavaGraphPanelAxisLabel(maxValue), top);
    drawRightAligned(buckJavaGraphPanelAxisLabel(middleValue), middleY);
    drawRightAligned(buckJavaGraphPanelAxisLabel(minValue), plotBottom);
    canvas.drawLine(Offset(left - 4, middleY), Offset(left + 4, middleY), axis);

    var lastLabelRight = -1000.0;
    for (final index in [0, 6, 12, 18]) {
      if (index >= points.length) continue;
      final px = x(points[index].timeMicroseconds);
      canvas.drawLine(Offset(px, zeroY - 4), Offset(px, zeroY + 4), axis);
      final painter = TextPainter(
        text: TextSpan(
            text: buckJavaGraphPanelAxisLabel(
              timeRange.graphPanelTickLabelValue(
                points[index].timeMicroseconds,
                plotRight - left,
              ),
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
        text: buckJavaGraphPanelAxisLabel(timeMax),
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
