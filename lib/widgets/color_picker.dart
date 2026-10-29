import 'package:flutter/material.dart';

import '../theme.dart';


/// Any-colour picker: palette, hue/saturation/brightness sliders and HEX.
/// Returns the colour as 0xRRGGBB.
Future<int?> pickColor(BuildContext context, {int initial = 0xFFFFFF}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ColorPickerSheet(initial: initial),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial});
  final int initial;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv = HSVColor.fromColor(Color(0xFF000000 | widget.initial));
  late final _hex = TextEditingController(text: _hexOf(_hsv.toColor()));

  static const _palette = [
    0xFFFFFF, 0xF5F5F5, 0xE0E0E0, 0x9E9E9E, 0x424242, 0x000000,
    0xD6E9FF, 0x90CAF9, 0x2196F3, 0x1E5BC6, 0x0D47A1, 0x00BCD4,
    0xC8E6C9, 0x66BB6A, 0x2E7D32, 0xFFF59D, 0xFFC107, 0xFF9800,
    0xFFCDD2, 0xEF5350, 0xC62828, 0xF8BBD0, 0xE91E63, 0x9C27B0,
  ];

  static String _hexOf(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _set(HSVColor c) => setState(() {
        _hsv = c;
        _hex.text = _hexOf(c.toColor());
      });

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.cs.outlineVariant),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _hex,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    prefixText: '# ', labelText: 'HEX', counterText: ''),
                onChanged: (v) {
                  final n = int.tryParse(v, radix: 16);
                  if (v.length == 6 && n != null) {
                    setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | n)));
                  }
                },
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in _palette)
              GestureDetector(
                onTap: () => _set(HSVColor.fromColor(Color(0xFF000000 | c))),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFF000000 | c),
                    shape: BoxShape.circle,
                    border: Border.all(color: context.cs.outlineVariant),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          _gradientSlider(
            'Hue',
            _hsv.hue / 360,
            [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()],
            (v) => _set(_hsv.withHue(v * 360)),
          ),
          _gradientSlider(
            'Saturation',
            _hsv.saturation,
            [_hsv.withSaturation(0).toColor(), _hsv.withSaturation(1).toColor()],
            (v) => _set(_hsv.withSaturation(v)),
          ),
          _gradientSlider(
            'Brightness',
            _hsv.value,
            [Colors.black, _hsv.withValue(1).toColor()],
            (v) => _set(_hsv.withValue(v)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, color.toARGB32() & 0xFFFFFF),
              child: const Text('Use this colour'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _gradientSlider(String label, double value, List<Color> colors,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (_, box) {
          void update(double dx) => onChanged((dx / box.maxWidth).clamp(0, 1));
          return GestureDetector(
            onPanDown: (d) => update(d.localPosition.dx),
            onPanUpdate: (d) => update(d.localPosition.dx),
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(children: [
                Positioned(
                  left: (value * box.maxWidth - 14).clamp(0, box.maxWidth - 28),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                ),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

/// Checkerboard used behind transparent images.
class CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const s = 12.0;
    final light = Paint()..color = const Color(0xFFFFFFFF);
    final dark = Paint()..color = const Color(0xFFDDDDDD);
    for (var y = 0.0; y < size.height; y += s) {
      for (var x = 0.0; x < size.width; x += s) {
        final odd = ((x / s).floor() + (y / s).floor()).isOdd;
        canvas.drawRect(Rect.fromLTWH(x, y, s, s), odd ? dark : light);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
