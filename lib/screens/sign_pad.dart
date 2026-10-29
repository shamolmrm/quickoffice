import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:signature/signature.dart';

import '../theme.dart';

/// Draw a signature; returns a trimmed transparent PNG.
class SignaturePadScreen extends StatefulWidget {
  const SignaturePadScreen({super.key});
  @override
  State<SignaturePadScreen> createState() => _SignaturePadScreenState();
}

class _SignaturePadScreenState extends State<SignaturePadScreen> {
  Color _color = const Color(0xFF0B1F6B);
  late SignatureController _c = _make();

  SignatureController _make() => SignatureController(
        penColor: _color,
        penStrokeWidth: 3.5,
        exportBackgroundColor: Colors.transparent,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (_c.isEmpty) return context.toast('Please sign first');
    final raw = await _c.toPngBytes();
    if (raw == null) return;
    final trimmed = await Isolate.run(() =>
        Uint8List.fromList(img.encodePng(img.trim(img.decodePng(raw)!, mode: img.TrimMode.transparent))));
    if (mounted) Navigator.pop(context, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw signature'),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: () => _c.undo()),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _c.clear()),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.cs.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              const Positioned(left: 24, right: 24, bottom: 60, child: Divider(color: Colors.black26)),
              Signature(controller: _c, backgroundColor: Colors.white),
            ]),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final c in const [Color(0xFF0B1F6B), Colors.black, Color(0xFFB91C1C)])
            GestureDetector(
              onTap: () => setState(() {
                final pts = _c.points;
                _color = c;
                _c.dispose();
                _c = _make()..points = pts;
              }),
              child: Container(
                margin: const EdgeInsets.all(8),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: _color == c ? AppColors.primary : Colors.transparent, width: 3),
                ),
              ),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _done, child: const Text('Use signature'))),
        ),
      ]),
    );
  }
}
