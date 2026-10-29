import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum SealShape { round, oval, rectangle }

class SealSpec {
  SealSpec({
    this.shape = SealShape.round,
    this.top = 'COMPANY NAME',
    this.bottom = 'DHAKA',
    this.center = '★',
    this.centerSub = '',
    this.color = const Color(0xFF1D4ED8),
    this.doubleRing = true,
  });
  SealShape shape;
  String top, bottom, center, centerSub;
  Color color;
  bool doubleRing;
}

/// Draws office seals; used for live preview and PNG export.
class SealPainter extends CustomPainter {
  SealPainter(this.s);
  final SealSpec s;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = s.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.018;
    final c = size.center(Offset.zero);
    if (s.shape == SealShape.rectangle) {
      _rect(canvas, size, ink);
      return;
    }
    final rx = size.width * 0.47, ry = s.shape == SealShape.oval ? size.height * 0.34 : size.height * 0.47;
    canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), ink);
    if (s.doubleRing) {
      canvas.drawOval(
          Rect.fromCenter(center: c, width: rx * 2 * 0.93, height: ry * 2 * 0.91),
          ink..strokeWidth = size.width * 0.008);
    }
    final inner = Rect.fromCenter(center: c, width: rx * 2 * 0.62, height: ry * 2 * 0.58);
    canvas.drawOval(inner, ink..strokeWidth = size.width * 0.01);

    final fs = size.width * 0.085;
    _arcText(canvas, c, rx * 0.78, ry * 0.76, s.top.toUpperCase(), fs, top: true);
    _arcText(canvas, c, rx * 0.78, ry * 0.76, s.bottom.toUpperCase(), fs * 0.9, top: false);
    // Separator stars on the ring.
    for (final a in [pi, 0.0]) {
      _text(canvas, '★', Offset(c.dx + cos(a) * rx * 0.78, c.dy + sin(a) * ry * 0.76), fs * 0.7);
    }
    _text(canvas, s.center, c.translate(0, s.centerSub.isEmpty ? 0 : -fs * 0.45), fs * (s.center.length > 6 ? 0.9 : 1.4),
        bold: true, maxWidth: inner.width * 0.9);
    if (s.centerSub.isNotEmpty) _text(canvas, s.centerSub, c.translate(0, fs * 0.75), fs * 0.62, maxWidth: inner.width * 0.9);
  }

  void _rect(Canvas canvas, Size size, Paint ink) {
    final r = Rect.fromLTWH(size.width * 0.03, size.height * 0.22, size.width * 0.94, size.height * 0.56);
    canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(size.width * 0.03)), ink);
    if (s.doubleRing) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r.deflate(size.width * 0.025), Radius.circular(size.width * 0.02)),
          ink..strokeWidth = size.width * 0.007);
    }
    final fs = size.width * 0.075;
    _text(canvas, s.top.toUpperCase(), Offset(r.center.dx, r.top + r.height * 0.27), fs, bold: true, maxWidth: r.width * 0.9);
    canvas.drawLine(Offset(r.left + r.width * 0.12, r.center.dy), Offset(r.right - r.width * 0.12, r.center.dy),
        ink..strokeWidth = size.width * 0.006);
    _text(canvas, [s.center, s.centerSub].where((e) => e.isNotEmpty && e != '★').join('  '),
        Offset(r.center.dx, r.top + r.height * 0.62), fs * 0.8, maxWidth: r.width * 0.9);
    _text(canvas, s.bottom.toUpperCase(), Offset(r.center.dx, r.top + r.height * 0.84), fs * 0.62, maxWidth: r.width * 0.9);
  }

  void _text(Canvas canvas, String text, Offset center, double size, {bool bold = false, double? maxWidth}) {
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: s.color, fontSize: size, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, letterSpacing: 1),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Writes text along the top (left→right) or bottom arc of an ellipse.
  void _arcText(Canvas canvas, Offset c, double rx, double ry, String text, double size, {required bool top}) {
    if (text.isEmpty) return;
    final style = TextStyle(color: s.color, fontSize: size, fontWeight: FontWeight.w800, letterSpacing: 2);
    final painters = [
      for (final ch in text.characters)
        TextPainter(text: TextSpan(text: ch, style: style), textDirection: TextDirection.ltr)..layout()
    ];
    final total = painters.fold<double>(0, (s, p) => s + p.width);
    final r = (rx + ry) / 2;
    final sweep = (total / r).clamp(0.0, pi * 0.92);
    var angle = top ? -pi / 2 - sweep / 2 : pi / 2 + sweep / 2;
    final scale = sweep / (total / r);
    for (final p in painters) {
      final step = p.width / r * scale;
      final mid = top ? angle + step / 2 : angle - step / 2;
      final pos = Offset(c.dx + cos(mid) * rx, c.dy + sin(mid) * ry);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(top ? mid + pi / 2 : mid - pi / 2);
      p.paint(canvas, Offset(-p.width / 2, -p.height / 2));
      canvas.restore();
      angle = top ? angle + step : angle - step;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  /// Transparent PNG at [px]×[px].
  static Future<Uint8List> toPng(SealSpec s, {double px = 700}) async {
    final rec = ui.PictureRecorder();
    SealPainter(s).paint(Canvas(rec), Size(px, px));
    final img = await rec.endRecording().toImage(px.toInt(), px.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
