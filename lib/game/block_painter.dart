import 'package:flutter/material.dart';

final _fill = Paint();
const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// Draws one tower block: rounded, with a soft highlight on top and shade below.
/// Uses flat overlays (no shader objects) because it is called for every visible block on every frame.
void drawBlock(Canvas c, double x, double y, double w, double h, Color color, {double alpha = 1}) {
  final bodyH = h - 2;
  final body = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, bodyH), const Radius.circular(6));
  c.drawRRect(body, _fill..color = color.withValues(alpha: alpha));
  // lit top half
  c.drawRRect(
    RRect.fromRectAndCorners(Rect.fromLTWH(x, y, w, bodyH * .5), topLeft: const Radius.circular(6), topRight: const Radius.circular(6)),
    _fill..color = _white.withValues(alpha: .16 * alpha),
  );
  // shaded bottom third
  c.drawRRect(
    RRect.fromRectAndCorners(Rect.fromLTWH(x, y + bodyH * .68, w, bodyH * .32), bottomLeft: const Radius.circular(6), bottomRight: const Radius.circular(6)),
    _fill..color = _black.withValues(alpha: .16 * alpha),
  );
  // glossy line
  if (w > 10) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 3, y + 2, w - 6, 3.5), const Radius.circular(2)), _fill..color = _white.withValues(alpha: .28 * alpha));
  }
}
