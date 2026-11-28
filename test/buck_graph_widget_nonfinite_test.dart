import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_waveforms.dart';

void main() {
  testWidgets(
    'Buck device painters render non-finite x and y samples in Arabic RTL',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const metrics = BuckDeviceMetrics(
        minimumVoltage: 0,
        maximumVoltage: 2,
        minimumCurrent: 0,
        maximumCurrent: 2,
        rmsCurrent: 1.5,
        averageCurrent: 1,
        acCurrent: 1.118033988749895,
      );

      List<BuckWaveformPoint> makePoints({
        bool firstTimeNaN = false,
        bool laterTimeNaN = false,
        bool firstValueNaN = false,
        double? laterValue,
      }) {
        return List.generate(20, (index) {
          var time = index.toDouble();
          if (firstTimeNaN && index == 0) {
            time = double.nan;
          } else if (laterTimeNaN && index == 7) {
            time = double.nan;
          }

          var value = index.isEven ? 1.0 : 2.0;
          if (firstValueNaN && index == 0) {
            value = double.nan;
          } else if (laterValue != null && index == 9) {
            value = laterValue;
          }
          return BuckWaveformPoint(time, value);
        });
      }

      BuckDeviceWaveform makeDevice({
        required String id,
        required String title,
        bool firstTimeNaN = false,
        bool laterTimeNaN = false,
        bool firstValueNaN = false,
        double? laterValue,
      }) {
        final samples = makePoints(
          firstTimeNaN: firstTimeNaN,
          laterTimeNaN: laterTimeNaN,
          firstValueNaN: firstValueNaN,
          laterValue: laterValue,
        );
        return BuckDeviceWaveform(
          id: id,
          title: title,
          voltage: samples,
          current: samples,
          metrics: metrics,
        );
      }

      final waveforms = BuckWaveformSet([
        // Keep finite segments visible while also exercising later NaN X and
        // positive-infinity Y coordinates.
        makeDevice(
          id: 'inputCapacitor',
          title: 'Input capacitor Ci',
          laterTimeNaN: true,
          laterValue: double.infinity,
        ),
        makeDevice(
          id: 'mosfet',
          title: 'MOSFET Q1',
          firstTimeNaN: true,
        ),
        makeDevice(
          id: 'inductor',
          title: 'Inductor L1',
          firstValueNaN: true,
        ),
        makeDevice(
          id: 'diode',
          title: 'Freewheel diode D1',
          laterValue: double.negativeInfinity,
        ),
        makeDevice(
          id: 'outputCapacitor',
          title: 'Output capacitor Co',
          laterValue: double.nan,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF0000),
              tertiary: Color(0xFF0000FF),
            ),
          ),
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: BuckDeviceWaveformsView(
                  waveforms: waveforms,
                  voltageLabel: 'الجهد',
                  currentLabel: 'التيار',
                  periodLabel: 'ثلاث دورات',
                  timeAxisLabel: 'المقياس الزمني (µs)',
                  deviceTitles: const {
                    'inputCapacitor': 'مكثف الدخل',
                    'mosfet': 'MOSFET Q1',
                    'inductor': 'المحث L1',
                    'diode': 'دايود التدوير الحر',
                    'outputCapacitor': 'مكثف الخرج',
                  },
                  metricLabels: const {
                    'minimumVoltage': 'أدنى جهد',
                    'maximumVoltage': 'أعلى جهد',
                    'minimumCurrent': 'أدنى تيار',
                    'maximumCurrent': 'أعلى تيار',
                    'rmsCurrent': 'تيار RMS',
                    'averageCurrent': 'متوسط التيار',
                    'acCurrent': 'تيار AC',
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chartFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter?.runtimeType.toString() == '_BuckTracePainter',
      );
      final charts = tester.widgetList<CustomPaint>(chartFinder).toList();
      expect(charts, hasLength(10));
      expect(find.text('الجهد (V)'), findsNWidgets(5));
      expect(find.text('التيار (A)'), findsNWidgets(5));
      expect(find.text('المقياس الزمني (µs)'), findsNWidgets(10));
      expect(tester.takeException(), isNull);

      for (var index = 0; index < charts.length; index++) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        charts[index].painter!.paint(canvas, const Size(220, 75));
        final picture = recorder.endRecording();

        if (index < 2) {
          final image = await picture.toImage(220, 75);
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(bytes, isNotNull);
          final expectedColor = index == 0
              ? const Color(0xFF0000FF)
              : const Color(0xFFFF0000);
          expect(
            _hasStrongColor(bytes!, expectedColor),
            isTrue,
            reason: index == 0
                ? 'Voltage trace should paint blue finite segments'
                : 'Current trace should paint red finite segments',
          );
          image.dispose();
        }
        picture.dispose();
      }
      expect(tester.takeException(), isNull);
    },
  );
}

bool _hasStrongColor(ByteData bytes, Color target) {
  for (var offset = 0; offset < bytes.lengthInBytes; offset += 4) {
    final alpha = bytes.getUint8(offset + 3);
    if (alpha < 200) continue;

    final red = bytes.getUint8(offset);
    final green = bytes.getUint8(offset + 1);
    final blue = bytes.getUint8(offset + 2);
    if ((red - target.red).abs() <= 40 &&
        (green - target.green).abs() <= 40 &&
        (blue - target.blue).abs() <= 40) {
      return true;
    }
  }
  return false;
}
