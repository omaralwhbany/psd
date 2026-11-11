import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_schematic.dart';

void main() {
  testWidgets(
    'Buck freewheel diode is filled and cathode faces the switch node like PSD5',
    (tester) async {
      const width = 360.0;
      final theme = ThemeData();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                child: SizedBox(
                  width: width,
                  child: const BuckSchematic(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        BuckSchematic.diodeCathodeBarY,
        lessThan(BuckSchematic.diodeTriangleApexY),
      );
      expect(
        BuckSchematic.diodeTriangleApexY,
        lessThan(BuckSchematic.diodeAnodeBaseY),
      );

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(data, isNotNull);

      final pixels = data!.buffer.asUint8List();
      final offset = (124 * image.width + 82) * 4;
      final diodePixel = Color.fromARGB(
        pixels[offset + 3],
        pixels[offset],
        pixels[offset + 1],
        pixels[offset + 2],
      );
      expect(diodePixel, theme.colorScheme.primary);
      image.dispose();
    },
  );
}
