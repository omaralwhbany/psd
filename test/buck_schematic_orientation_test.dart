import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_schematic.dart';

void main() {
  test('Buck schematic follows the original non-synchronous power path', () {
    expect(
      BuckSchematic.inputCapacitorX,
      lessThan(BuckSchematic.mosfetLeftX),
    );
    expect(
      BuckSchematic.mosfetRightX,
      lessThan(BuckSchematic.switchNodeX),
    );
    expect(BuckSchematic.diodeConnectionX, BuckSchematic.switchNodeX);
    expect(
      BuckSchematic.switchNodeX,
      lessThan(BuckSchematic.inductorStartX),
    );
    expect(
      BuckSchematic.inductorStartX,
      lessThan(BuckSchematic.inductorEndX),
    );
    expect(
      BuckSchematic.inductorEndX,
      lessThan(BuckSchematic.outputCapacitorX),
    );
    expect(
      BuckSchematic.outputCapacitorX,
      lessThan(BuckSchematic.railRightX),
    );
    expect(
      BuckSchematic.diodeCathodeBarY,
      lessThan(BuckSchematic.diodeTriangleApexY),
    );
    expect(
      BuckSchematic.diodeTriangleApexY,
      lessThan(BuckSchematic.diodeAnodeBaseY),
    );
    expect(
      BuckSchematic.diodeAnodeBaseY,
      lessThan(BuckSchematic.railBottomY),
    );
  });

  testWidgets('Buck schematic fits narrow and wide layouts without clipping', (
    tester,
  ) async {
    for (final width in [320.0, 720.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: BuckSchematic.designHeight,
              child: const BuckSchematic(),
            ),
          ),
        ),
      );

      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.fit, BoxFit.contain);
      expect(
        tester.getSize(find.descendant(
          of: find.byType(BuckSchematic),
          matching: find.byType(CustomPaint),
        )),
        const Size(
          BuckSchematic.designWidth,
          BuckSchematic.designHeight,
        ),
      );
    }
  });
}
