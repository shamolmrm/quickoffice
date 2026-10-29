import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_service.dart';
import '../services/pdf_service.dart';
import '../theme.dart';
import '../widgets/color_picker.dart';
import '../widgets/common.dart';

/// Professional one-page CV with photo; AI polishes the profile summary.
class CvScreen extends StatefulWidget {
  const CvScreen({super.key});
  @override
  State<CvScreen> createState() => _CvScreenState();
}

class _CvScreenState extends State<CvScreen> {
  static const _fields = [
    ('name', 'Full name', 1),
    ('title', 'Job title (e.g. Accountant)', 1),
    ('phone', 'Phone', 1),
    ('email', 'Email', 1),
    ('address', 'Address', 1),
    ('linkedin', 'LinkedIn / portfolio', 1),
    ('summary', 'Profile summary', 4),
    ('experience', 'Experience (one per line: Role – Company, years)', 5),
    ('education', 'Education (one per line)', 4),
    ('skills', 'Skills (comma separated)', 2),
    ('languages', 'Languages (comma separated)', 1),
    ('certificates', 'Training & certificates', 3),
    ('references', 'References', 3),
  ];

  final Map<String, TextEditingController> _c = {
    for (final f in _fields) f.$1: TextEditingController(),
  };
  String? _photo;
  int _color = 0xFF0F3D5E;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final raw = p.getString('cv');
      if (raw == null) return;
      final j = Map<String, dynamic>.from(jsonDecode(raw));
      setState(() {
        for (final e in _c.entries) {
          e.value.text = (j[e.key] ?? '').toString();
        }
        _photo = j['_photo'];
        _color = j['_color'] ?? _color;
      });
    });
  }

  Map<String, String> get _data => {for (final e in _c.entries) e.key: e.value.text};

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('cv', jsonEncode({..._data, '_photo': _photo, '_color': _color}));
  }

  Future<void> _improve() async {
    final ai = context.read<AiService>();
    final src = [_c['title']!.text, _c['summary']!.text, _c['experience']!.text, _c['skills']!.text].join('\n');
    final out = await withProgress(
      context,
      'AI is polishing your profile…',
      () => ai.improve(src,
          'Write a strong 3-sentence professional CV profile summary in English from this information. No first-person "I".'),
    );
    if (out != null) setState(() => _c['summary']!.text = out);
  }

  Future<void> _preview() async {
    if (_c['name']!.text.trim().isEmpty) return context.toast('Enter your name');
    await _persist();
    if (!mounted) return;
    final wm = !isPremium(context);
    final bytes = await withProgress(context, 'Creating CV…', () => PdfService.cv(_data, _photo, _color, watermark: wm));
    if (bytes == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(title: 'CV ${_c['name']!.text}', bytes: bytes)));
  }

  @override
  void dispose() {
    _persist();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CV / Resume Maker')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          GestureDetector(
            onTap: () async {
              final p = await pickImageToStore(context);
              if (p != null) setState(() => _photo = p);
            },
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: fileExists(_photo) ? FileImage(File(_photo!)) : null,
              child: fileExists(_photo) ? null : const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Photo & colour', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final c in const [0xFF0F3D5E, 0xFF0E9F6E, 0xFF6D28D9, 0xFFB91C1C, 0xFF111827])
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(c),
                      child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  ),
                GestureDetector(
                  onTap: () async {
                    final c = await pickColor(context, initial: _color & 0xFFFFFF);
                    if (c != null) setState(() => _color = 0xFF000000 | c);
                  },
                  child: const CircleAvatar(radius: 15, child: Icon(Icons.palette_outlined, size: 16)),
                ),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        for (final f in _fields) ...[
          TextField(
            controller: _c[f.$1],
            minLines: f.$3,
            maxLines: f.$3 == 1 ? 1 : null,
            decoration: InputDecoration(
              labelText: f.$2,
              alignLabelWithHint: f.$3 > 1,
              border: f.$3 > 1 ? OutlineInputBorder(borderRadius: BorderRadius.circular(14)) : null,
              suffixIcon: f.$1 == 'summary'
                  ? IconButton(tooltip: 'Write with AI', icon: const Icon(Icons.auto_awesome, color: AppColors.accent), onPressed: _improve)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(onPressed: _preview, icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('Create CV PDF')),
        ),
      ),
    );
  }
}
