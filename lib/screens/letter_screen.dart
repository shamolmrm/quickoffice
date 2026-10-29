import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/pdf_service.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// (type, icon, hint for the details field)
const letterTypes = [
  ('Appointment Letter', Icons.how_to_reg_rounded, 'Name, position, salary, joining date, probation'),
  ('Offer Letter', Icons.handshake_rounded, 'Candidate, role, salary, start date, benefits'),
  ('Experience Certificate', Icons.workspace_premium_rounded, 'Name, designation, from–to dates, conduct'),
  ('Salary Certificate', Icons.account_balance_wallet_rounded, 'Name, designation, monthly salary, purpose (bank, visa)'),
  ('NOC (No Objection)', Icons.verified_user_rounded, 'Name, purpose (visa, travel, higher study), dates'),
  ('Leave Application', Icons.beach_access_rounded, 'Your name, reason, from–to dates'),
  ('Resignation Letter', Icons.exit_to_app_rounded, 'Name, position, last working day, reason'),
  ('Warning Letter', Icons.report_rounded, 'Employee, issue, date, expected correction'),
  ('Termination Letter', Icons.person_off_rounded, 'Employee, reason, last day, dues'),
  ('Recommendation Letter', Icons.thumb_up_alt_rounded, 'Person, relationship, strengths, purpose'),
  ('Business Proposal', Icons.lightbulb_rounded, 'To whom, what you offer, price, benefits'),
  ('Custom Letter', Icons.edit_note_rounded, 'Describe what the letter should say'),
];

class LetterListScreen extends StatelessWidget {
  const LetterListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final letters = [...store.letters]..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: const Text('Official Letters')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: AppColors.aiGradient, borderRadius: BorderRadius.circular(20)),
          child: const Row(children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 34),
            SizedBox(width: 12),
            Expanded(
              child: Text('AI writes the letter on your letterhead with signature & seal — in English or Bangla.',
                  style: TextStyle(color: Colors.white, height: 1.4)),
            ),
          ]),
        ),
        const SectionTitle('Choose a letter'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: [
            for (final t in letterTypes)
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LetterEditorScreen(letter: Letter(id: store.newId(), type: t.$1, date: DateTime.now())))),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(t.$2, color: AppColors.accent, size: 30),
                      const SizedBox(height: 8),
                      Text(t.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
        if (letters.isNotEmpty) ...[
          SectionTitle('Saved (${letters.length})'),
          for (final l in letters)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l.subject.isEmpty ? l.type : l.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${l.type} · ${dateFmt.format(l.date)}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LetterEditorScreen(letter: l))),
              ),
            ),
        ],
      ]),
    );
  }
}

class LetterEditorScreen extends StatefulWidget {
  const LetterEditorScreen({super.key, required this.letter});
  final Letter letter;
  @override
  State<LetterEditorScreen> createState() => _LetterEditorScreenState();
}

class _LetterEditorScreenState extends State<LetterEditorScreen> {
  late final Letter l = Letter.fromJson(widget.letter.toJson());
  late final _to = TextEditingController(text: l.to);
  late final _subject = TextEditingController(text: l.subject);
  late final _body = TextEditingController(text: l.body);
  final _details = TextEditingController();
  String _lang = 'English';

  String get _hint => letterTypes.firstWhere((t) => t.$1 == l.type, orElse: () => letterTypes.last).$3;

  Future<void> _write() async {
    if (_details.text.trim().isEmpty) return context.toast('Add a few details first');
    final ai = context.read<AiService>();
    final company = context.read<Store>().business.name;
    final r = await withProgress(
      context,
      'AI is writing your letter…',
      () => ai.letter(type: l.type, details: _details.text, company: company, language: _lang),
    );
    if (r == null) return;
    setState(() {
      _subject.text = r.subject;
      _body.text = r.body;
    });
  }

  void _sync() => l
    ..to = _to.text.trim()
    ..subject = _subject.text.trim()
    ..body = _body.text.trim();

  Future<void> _preview() async {
    _sync();
    if (l.body.isEmpty) return context.toast('Write or generate the letter first');
    final store = context.read<Store>();
    await store.saveLetter(l);
    if (!mounted) return;
    final wm = !isPremium(context);
    final bytes = await withProgress(context, 'Creating PDF…', () => PdfService.letter(store.business, l, watermark: wm));
    if (bytes == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfPreviewScreen(title: l.type, bytes: bytes)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l.type),
        actions: [
          if (context.read<Store>().letters.any((x) => x.id == l.id))
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final store = context.read<Store>();
                if (await confirm(context, 'Delete letter?', '')) {
                  await store.deleteLetter(l);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
                SizedBox(width: 6),
                Text('Write with AI', style: TextStyle(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _details,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(labelText: 'Details', hintText: _hint),
              ),
              const SizedBox(height: 10),
              Row(children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'English', label: Text('English')),
                    ButtonSegment(value: 'Bangla', label: Text('বাংলা')),
                  ],
                  selected: {_lang},
                  onSelectionChanged: (v) => setState(() => _lang = v.first),
                ),
                const Spacer(),
                FilledButton.icon(onPressed: _write, icon: const Icon(Icons.auto_awesome, size: 18), label: const Text('Write')),
              ]),
            ]),
          ),
        ),
        const SectionTitle('Letter'),
        TextField(controller: _to, maxLines: 3, decoration: const InputDecoration(labelText: 'To (name, designation, address)')),
        const SizedBox(height: 10),
        TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
        const SizedBox(height: 10),
        TextField(
          controller: _body,
          minLines: 10,
          maxLines: null,
          decoration: InputDecoration(
            labelText: 'Body',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 8),
        Text('Your letterhead, date, signature and seal are added automatically.',
            style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12)),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(onPressed: _preview, icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('Save & preview PDF')),
        ),
      ),
    );
  }
}
