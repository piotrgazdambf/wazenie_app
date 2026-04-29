import 'package:flutter/material.dart';

/// Ikona drewnianej skrzyni na owoce rysowana przez CustomPainter.
/// Użycie: CrateIcon(size: 24, color: Colors.white)
class CrateIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CrateIcon({super.key, this.size = 24, this.color = Colors.brown});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _CratePainter(color),
      );
}

class _CratePainter extends CustomPainter {
  final Color color;
  const _CratePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // wymiary skrzyni
    final left   = w * 0.06;
    final right  = w * 0.94;
    final top    = h * 0.18;
    final bottom = h * 0.88;
    final cw     = right - left;
    final ch     = bottom - top;

    // wypełnienie tła
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), fillPaint);

    // ramka zewnętrzna
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, top, right, bottom),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(frame, paint);

    // poziome listwy (3 deski)
    final slat1 = top + ch * 0.30;
    final slat2 = top + ch * 0.57;
    canvas.drawLine(Offset(left, slat1), Offset(right, slat1), paint);
    canvas.drawLine(Offset(left, slat2), Offset(right, slat2), paint);

    // pionowe słupki (2 wewnętrzne)
    final post1 = left + cw * 0.33;
    final post2 = left + cw * 0.67;
    canvas.drawLine(Offset(post1, top), Offset(post1, bottom), paint);
    canvas.drawLine(Offset(post2, top), Offset(post2, bottom), paint);

    // uchwyt lewy
    final hGap  = w * 0.09;
    final hTop  = top - h * 0.04;
    final hBot  = top + h * 0.10;
    final hLeft = left + hGap;
    final hRight = left + cw * 0.32 - hGap;
    final handlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(hLeft, hBot), Offset(hLeft, hTop), handlePaint);
    canvas.drawLine(Offset(hLeft, hTop), Offset(hRight, hTop), handlePaint);
    canvas.drawLine(Offset(hRight, hTop), Offset(hRight, hBot), handlePaint);

    // uchwyt prawy
    final hrLeft  = left + cw * 0.68 + hGap;
    final hrRight = right - hGap;
    canvas.drawLine(Offset(hrLeft, hBot), Offset(hrLeft, hTop), handlePaint);
    canvas.drawLine(Offset(hrLeft, hTop), Offset(hrRight, hTop), handlePaint);
    canvas.drawLine(Offset(hrRight, hTop), Offset(hrRight, hBot), handlePaint);
  }

  @override
  bool shouldRepaint(_CratePainter old) => old.color != color;
}
