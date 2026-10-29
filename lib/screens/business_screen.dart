import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/pdf_service.dart';
import '../services/settings.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/color_picker.dart';
import '../widgets/common.dart';
import 'seal_screen.dart';
import 'sign_pad.dart';

const currencies = ['৳', '\$', '₹', '€', '£', 'Rs', 'SAR', 'AED', 'RM', '₦', '₱', 'Rp'];

/// Business profile: shown once at first launch and from Settings.
class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key, this.firstRun = false});
  final bool firstRun;
  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  late final b = context.read<Store>().business;
  late final _name = TextEditingController(text: b.name);
  late final _tagline = TextEditingController(text: b.tagline);
  late final _address = TextEditingController(text: b.address);
  late final _phone = TextEditingController(text: b.phone);
  late final _email = TextEditingController(text: b.email);
  late final _website = TextEditingController(text: b.website);
  late final _tax = TextEditingController(text: b.taxId);
  late final _taxRate = TextEditingController(text: b.taxRate == 0 ? '' : '${b.taxRate}');
  late final _pay = TextEditingController(text: b.paymentInfo);
  late final _terms = TextEditingController(text: b.terms);

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return context.toast('Enter your business name');
    final store = context.read<Store>();
    b
      ..name = _name.text.trim()
      ..tagline = _tagline.text.trim()
      ..address = _address.text.trim()
      ..phone = _phone.text.trim()
      ..email = _email.text.trim()
      ..website = _website.text.trim()
      ..taxId = _tax.text.trim()
      ..taxRate = double.tryParse(_taxRate.text) ?? 0
      ..paymentInfo = _pay.text.trim()
      ..terms = _terms.text.trim();
    await store.save();
    if (!mounted) return;
    if (widget.firstRun) {
      context.read<AppSettings>().finishOnboarding();
    } else {
      Navigator.pop(context);
    }
  }

  Widget _field(TextEditingController c, String label, {IconData? icon, int lines = 1, TextInputType? type, String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: lines,
          keyboardType: type,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.cs.outlineVariant)),
          ),
        ),
      );

  Widget _imageTile(String title, String? path, IconData icon, VoidCallback onPick, VoidCallback onClear) => Expanded(
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cs.outlineVariant),
            ),
            child: Stack(children: [
              Center(
                child: fileExists(path)
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.file(File(path!), fit: BoxFit.contain, key: ValueKey(path)))
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, color: AppColors.primary),
                        const SizedBox(height: 6),
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
              ),
              if (fileExists(path))
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClear),
                ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.firstRun,
        title: Text(widget.firstRun ? 'Set up your business' : 'Business profile'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        if (widget.firstRun) ...[
          Row(children: [
            const AppLogo(size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Add your details once — they appear on every invoice, receipt and letter.',
                  style: TextStyle(color: context.cs.onSurfaceVariant)),
            ),
          ]),
          const SizedBox(height: 18),
        ],
        Row(children: [
          _imageTile('Logo', b.logoPath, Icons.add_photo_alternate_outlined, () async {
            final p = await pickImageToStore(context);
            if (p != null) setState(() => b.logoPath = p);
          }, () => setState(() => b.logoPath = null)),
          const SizedBox(width: 10),
          _imageTile('Signature', b.signaturePath, Icons.gesture_rounded, () async {
            final png = await Navigator.of(context)
                .push<Uint8List>(MaterialPageRoute(builder: (_) => const SignaturePadScreen()));
            if (png == null) return;
            final p = await store.saveMedia(png, 'png');
            setState(() => b.signaturePath = p);
          }, () => setState(() => b.signaturePath = null)),
          const SizedBox(width: 10),
          _imageTile('Seal', b.sealPath, Icons.verified_outlined, () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SealScreen(forBusiness: true)));
            setState(() {});
          }, () => setState(() => b.sealPath = null)),
        ]),
        const SizedBox(height: 18),
        _field(_name, 'Business name *', icon: Icons.store_rounded),
        _field(_tagline, 'Tagline (optional)', icon: Icons.short_text),
        _field(_address, 'Address', icon: Icons.place_outlined, lines: 2),
        _field(_phone, 'Phone', icon: Icons.call_outlined, type: TextInputType.phone),
        _field(_email, 'Email', icon: Icons.mail_outline, type: TextInputType.emailAddress),
        _field(_website, 'Website / Facebook page', icon: Icons.language),
        _field(_tax, 'Tax ID / BIN / GST / VAT no.', icon: Icons.badge_outlined),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: currencies.contains(b.currency) ? b.currency : '৳',
              decoration: InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [for (final c in currencies) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => b.currency = v!,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _field(_taxRate, 'Default VAT/Tax %', type: TextInputType.number)),
        ]),
        const SizedBox(height: 4),
        _field(_pay, 'Payment details (shown with QR)', icon: Icons.account_balance_outlined, lines: 3,
            hint: 'bKash: 017XXXXXXXX\nBank: City Bank, A/C 1234…'),
        _field(_terms, 'Default terms / thank-you note', icon: Icons.notes_rounded, lines: 2),
        const SectionTitle('Invoice design'),
        Wrap(spacing: 8, children: [
          for (var i = 0; i < PdfService.templates.length; i++)
            ChoiceChip(
              label: Text(PdfService.templates[i]),
              selected: b.template == i,
              onSelected: (_) => setState(() => b.template = i),
            ),
        ]),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Brand colour'),
          trailing: GestureDetector(
            onTap: () async {
              final c = await pickColor(context, initial: b.brandColor & 0xFFFFFF);
              if (c != null) setState(() => b.brandColor = 0xFF000000 | c);
            },
            child: CircleAvatar(backgroundColor: Color(b.brandColor), radius: 18),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _save, child: Text(widget.firstRun ? 'Start' : 'Save')),
        ),
      ),
    );
  }
}
