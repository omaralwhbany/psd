import 'package:flutter_test/flutter_test.dart';
import 'package:psd/topologies/buck/buck_schematic.dart';

void main() {
  test(
    'Buck freewheel diode cathode faces the switch node like the PSD5 image',
    () {
    expect(
      BuckSchematic.diodeCathodeBarY,
      lessThan(BuckSchematic.diodeTriangleApexY),
    );
    expect(
      BuckSchematic.diodeTriangleApexY,
      lessThan(BuckSchematic.diodeAnodeBaseY),
    );
  });
}
