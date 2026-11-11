import 'package:flutter/material.dart';

class BuckSchematic extends StatelessWidget {
  const BuckSchematic({super.key});

  static const double designWidth = 360;
  static const double designHeight = 190;
  static const double railLeftX = 16;
  static const double railRightX = 344;
  static const double railTopY = 70;
  static const double railBottomY = 145;
  static const double inputCapacitorX = 48;
  static const double mosfetLeftX = 82;
  static const double mosfetRightX = 122;
  static const double switchNodeX = 150;
  static const double diodeConnectionX = switchNodeX;
  static const double inductorStartX = 170;
  static const double inductorEndX = 250;
  static const double outputCapacitorX = 300;
  static const double capacitorUpperPlateY = 108;
  static const double capacitorLowerPlateY = 116;
  static const double diodeCathodeBarY = 108;
  static const double diodeTriangleApexY = 112;
  static const double diodeAnodeBaseY = 132;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: designHeight,
        width: double.infinity,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: designWidth,
              height: designHeight,
              child: CustomPaint(
                painter: _BuckPainter(
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      );
}

class _BuckPainter extends CustomPainter {
  _BuckPainter(this.accent, this.ink);

  final Color accent;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / BuckSchematic.designWidth;
    final scaleY = size.height / BuckSchematic.designHeight;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final wire = Paint()
      ..color = ink
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final part = Paint()
      ..color = accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final diodeFill = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;
    final node = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;

    void label(String value, double x, double y) {
      final tp = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: ink,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
    }

    const top = BuckSchematic.railTopY;
    const bottom = BuckSchematic.railBottomY;
    const inputCap = BuckSchematic.inputCapacitorX;
    const outputCap = BuckSchematic.outputCapacitorX;
    const switchNode = BuckSchematic.diodeConnectionX;

    // Input and return rails remain separate at their open terminals.
    canvas.drawLine(
      const Offset(BuckSchematic.railLeftX, top),
      const Offset(BuckSchematic.mosfetLeftX, top),
      wire,
    );
    canvas.drawLine(
      const Offset(BuckSchematic.mosfetRightX, top),
      const Offset(BuckSchematic.inductorStartX, top),
      wire,
    );
    canvas.drawLine(
      const Offset(BuckSchematic.inductorEndX, top),
      const Offset(BuckSchematic.railRightX, top),
      wire,
    );
    canvas.drawLine(
      const Offset(BuckSchematic.railLeftX, bottom),
      const Offset(BuckSchematic.railRightX, bottom),
      wire,
    );

    // Input capacitor Ci is connected across the input rails, before Q1.
    canvas.drawLine(
      const Offset(inputCap, top),
      const Offset(inputCap, BuckSchematic.capacitorUpperPlateY),
      wire,
    );
    canvas.drawLine(
      const Offset(inputCap - 12, BuckSchematic.capacitorUpperPlateY),
      const Offset(inputCap + 12, BuckSchematic.capacitorUpperPlateY),
      part,
    );
    canvas.drawLine(
      const Offset(inputCap - 12, BuckSchematic.capacitorLowerPlateY),
      const Offset(inputCap + 12, BuckSchematic.capacitorLowerPlateY),
      part,
    );
    canvas.drawLine(
      const Offset(inputCap, BuckSchematic.capacitorLowerPlateY),
      const Offset(inputCap, bottom),
      wire,
    );

    // Q1 is in series between VIN and the switch node.
    const mosfet = Rect.fromLTRB(
      BuckSchematic.mosfetLeftX,
      55,
      BuckSchematic.mosfetRightX,
      85,
    );
    canvas.drawRect(mosfet, part);
    canvas.drawRect(mosfet, fill);

    // D1 cathode is tied to the Q1/L1 switch node; its anode returns to ground.
    canvas.drawLine(
      const Offset(switchNode, top),
      const Offset(switchNode, BuckSchematic.diodeCathodeBarY),
      wire,
    );
    canvas.drawLine(
      const Offset(switchNode - 12, BuckSchematic.diodeCathodeBarY),
      const Offset(switchNode + 12, BuckSchematic.diodeCathodeBarY),
      part,
    );
    final diode = Path()
      ..moveTo(switchNode - 12, BuckSchematic.diodeAnodeBaseY)
      ..lineTo(switchNode + 12, BuckSchematic.diodeAnodeBaseY)
      ..lineTo(switchNode, BuckSchematic.diodeTriangleApexY)
      ..close();
    canvas.drawPath(diode, diodeFill);
    canvas.drawPath(diode, part);
    canvas.drawLine(
      const Offset(switchNode, BuckSchematic.diodeAnodeBaseY),
      const Offset(switchNode, bottom),
      wire,
    );

    // L1 is in series after the switch node.
    final coil = Path()..moveTo(BuckSchematic.inductorStartX, top);
    for (var i = 0; i < 4; i++) {
      coil.arcToPoint(
        Offset(BuckSchematic.inductorStartX + 20 + i * 20, top),
        radius: const Radius.circular(10),
        clockwise: false,
      );
    }
    canvas.drawPath(coil, part);

    // Output capacitor Co is connected across the output rails.
    canvas.drawLine(
      const Offset(outputCap, top),
      const Offset(outputCap, BuckSchematic.capacitorUpperPlateY),
      wire,
    );
    canvas.drawLine(
      const Offset(outputCap - 12, BuckSchematic.capacitorUpperPlateY),
      const Offset(outputCap + 12, BuckSchematic.capacitorUpperPlateY),
      part,
    );
    canvas.drawLine(
      const Offset(outputCap - 12, BuckSchematic.capacitorLowerPlateY),
      const Offset(outputCap + 12, BuckSchematic.capacitorLowerPlateY),
      part,
    );
    canvas.drawLine(
      const Offset(outputCap, BuckSchematic.capacitorLowerPlateY),
      const Offset(outputCap, bottom),
      wire,
    );

    for (final x in [BuckSchematic.railLeftX, BuckSchematic.railRightX]) {
      canvas.drawCircle(Offset(x, top), 2.5, node);
      canvas.drawCircle(Offset(x, bottom), 2.5, node);
    }

    label('VIN', 16, 42);
    label('Q1', 94, 37);
    label('Ci', 60, 109);
    label('D1', 165, 111);
    label('L1', 204, 40);
    label('Co', 310, 109);
    label('VOUT', 310, 42);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BuckPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.ink != ink;
}
