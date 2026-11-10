import 'package:flutter/material.dart';

class BuckSchematic extends StatelessWidget {
  const BuckSchematic({super.key});

  // In an asynchronous Buck, the freewheel diode anode is at ground and
  // its cathode faces the switch node.
  static const double diodeCathodeBarY = 112;
  static const double diodeTriangleApexY = 114;
  static const double diodeAnodeBaseY = 132;
  @override
  Widget build(BuildContext context) => SizedBox(height: 190, width: double.infinity, child: CustomPaint(painter: _BuckPainter(Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.onSurface)));
}

class _BuckPainter extends CustomPainter {
  _BuckPainter(this.accent, this.ink);
  final Color accent;
  final Color ink;
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 360;
    canvas.save();
    canvas.scale(sx, sx);
    final wire = Paint()..color = ink..strokeWidth = 2..style = PaintingStyle.stroke;
    final part = Paint()..color = accent..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final fill = Paint()..color = accent.withValues(alpha: 0.08)..style = PaintingStyle.fill;
    void label(String value, double x, double y) {
      final tp = TextPainter(text: TextSpan(text: value, style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x, y));
    }
    canvas.drawLine(const Offset(16, 70), const Offset(65, 70), wire);
    canvas.drawRect(const Rect.fromLTWH(65, 55, 34, 30), part);
    canvas.drawRect(const Rect.fromLTWH(65, 55, 34, 30), fill);
    label('Q1', 76, 63);
    canvas.drawLine(const Offset(99, 70), const Offset(130, 70), wire);
    final coil = Path()..moveTo(130, 70);
    for (var i = 0; i < 4; i++) {
      coil.arcToPoint(Offset(150 + i * 20, 70), radius: const Radius.circular(10), clockwise: false);
    }
    canvas.drawPath(coil, part);
    canvas.drawLine(const Offset(210, 70), const Offset(344, 70), wire);
    canvas.drawLine(const Offset(280, 70), const Offset(280, 108), wire);
    canvas.drawLine(const Offset(268, 108), const Offset(292, 108), part);
    canvas.drawLine(const Offset(268, 116), const Offset(292, 116), part);
    canvas.drawLine(const Offset(280, 116), const Offset(280, 145), wire);
    canvas.drawLine(const Offset(16, 145), const Offset(344, 145), wire);
    canvas.drawLine(const Offset(16, 70), const Offset(16, 145), wire);
    canvas.drawLine(const Offset(344, 70), const Offset(344, 145), wire);
    canvas.drawLine(const Offset(82, 85), const Offset(82, BuckSchematic.diodeCathodeBarY), wire);
    final diode = Path()
      ..moveTo(70, BuckSchematic.diodeAnodeBaseY)
      ..lineTo(94, BuckSchematic.diodeAnodeBaseY)
      ..lineTo(82, BuckSchematic.diodeTriangleApexY)
      ..close();
    canvas.drawPath(diode, part);
    canvas.drawLine(
      const Offset(70, BuckSchematic.diodeCathodeBarY),
      const Offset(94, BuckSchematic.diodeCathodeBarY),
      part,
    );
    canvas.drawLine(
      const Offset(82, BuckSchematic.diodeAnodeBaseY),
      const Offset(82, 145),
      wire,
    );
    label('VIN', 16, 42); label('SWITCH', 57, 30); label('D1', 99, 111);
    label('L1', 157, 40); label('COUT', 295, 108); label('VOUT', 310, 42); label('GND', 18, 151);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _BuckPainter oldDelegate) => oldDelegate.accent != accent || oldDelegate.ink != ink;
}
