import 'package:flutter/material.dart';

/// Draws one tower block: rounded, with a soft vertical gradient and a glossy top edge.
void drawBlock(Canvas c, double x, double y, double w, double h, Color color, {double alpha = 1}) {
  final rect = Rect.fromLTWH(x, y, w, h - 2);
  final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
  final p = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(color, Colors.white, .25)!.withValues(alpha: alpha),
        color.withValues(alpha: alpha),
        Color.lerp(color, Colors.black, .18)!.withValues(alpha: alpha),
      ],
    ).createShader(rect);
  c.drawRRect(rr, p);
  final gloss = Paint()..color = Colors.white.withValues(alpha: .22 * alpha);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 3, y + 2, (w - 6).clamp(0, w), 4), const Radius.circular(2)), gloss);
}
