import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/seal_painter.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Office seal / stamp designer. Saves as the business seal or shares PNG.
class SealScreen extends StatefulWidget {
  const SealScreen({super.key, this.forBusiness = false});
  final bool forBusiness;
  @override
  State<SealScreen> createState() => _SealScreenState();
}

class _SealScreenState extends State<SealScreen> {
  late final SealSpec _s = SealSpec(
    top: context.read<Store>().business.name.isEmpty ? 'YOUR COMPANY' : context.read<Store>().business.name,
    bottom: _city(context.read<Store>().business.address),
  );
  late final _top = TextEditingController(text: _s.top);
  late final _bottom = TextEditingController(text: _s.bottom);
  late final _center = TextEditingController(text: _s.center);
  late final _sub = TextEditingController(text: _s.centerSub);

  static String _city(String address) {
    final parts = address.split(RegExp(r'[,\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'DHAKA' : parts.last;
  }

  static const _colors = [
    Color(0xFF1D4ED8),
    Color(0xFF6D28D9),
    Color(0xFFB91C1C),
    Color(0xFF047857),
    Color(0xFF111827),
  ];

  static const _presets = ['★', 'APPROVED', 'PAID', 'RECEIVED', 'VERIFIED', 'ORIGINAL', 'CONFIDENTIAL'];

  Future<void> _save({required bool asBusiness}) async {
    final store = context.read<Store>();
    final png = await SealPainter.toPng(_s);
    if (asBusiness) {
      store.business.sealPath = await store.saveMedia(png, 'png');
      await store.save();
      if (!mounted) return;
      context.toast('Seal added to your documents');
      Navigator.pop(context);
    } else {
      final f = await store.export('seal_${DateTime.now().millisecondsSinceEpoch}.png', png);
      if (mounted) FileActions.shareFile(context, f.path);
    }
  }

  Widget _input(TextEditingController c, String label, void Function(String) set) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          onChanged: (v) => setState(() => set(v)),
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seal & Stamp Maker')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.all(12),
            child: CustomPaint(painter: SealPainter(_s)),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<SealShape>(
          segments: const [
            ButtonSegment(value: SealShape.round, label: Text('Round'), icon: Icon(Icons.circle_outlined)),
            ButtonSegment(value: SealShape.oval, label: Text('Oval')),
            ButtonSegment(value: SealShape.rectangle, label: Text('Square'), icon: Icon(Icons.crop_square)),
          ],
          selected: {_s.shape},
          onSelectionChanged: (v) => setState(() => _s.shape = v.first),
        ),
        const SizedBox(height: 16),
        _input(_top, 'Top text (company name)', (v) => _s.top = v),
        _input(_bottom, 'Bottom text (city / reg. no.)', (v) => _s.bottom = v),
        _input(_center, 'Center text', (v) => _s.center = v),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in _presets)
            ActionChip(
              label: Text(p),
              onPressed: () => setState(() {
                _center.text = p;
                _s.center = p;
              }),
            ),
        ]),
        const SizedBox(height: 10),
        _input(_sub, 'Small center line (e.g. Est. 2020, date)', (v) => _s.centerSub = v),
        Row(children: [
          const Text('Ink', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          for (final c in _colors)
            GestureDetector(
              onTap: () => setState(() => _s.color = c),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: _s.color == c ? AppColors.primary : Colors.transparent, width: 3),
                ),
              ),
            ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Double border'),
          value: _s.doubleRing,
          onChanged: (v) => setState(() => _s.doubleRing = v),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                onPressed: () => _save(asBusiness: false),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share PNG'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _save(asBusiness: true),
                icon: const Icon(Icons.verified_rounded),
                label: Text(widget.forBusiness ? 'Use this seal' : 'Use on documents'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
