import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/ad_gate.dart';
import '../services/ai_service.dart';
import '../services/pdf_service.dart';
import '../services/reminder_service.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'doc_editor_screen.dart';

class DocViewScreen extends StatelessWidget {
  const DocViewScreen({super.key, required this.docId});
  final String docId;

  Future<void> _preview(BuildContext context, BizDoc d) async {
    final store = context.read<Store>();
    final watermark = !isPremium(context);
    final bytes = await withProgress(context, 'Creating PDF…', () => PdfService.document(store.business, d, watermark: watermark));
    if (bytes == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfPreviewScreen(
        title: '${d.kind.label} ${d.number}',
        bytes: bytes,
        shareText: '${d.kind.label} ${d.number} from ${store.business.name} — ${fmtMoney(d.total, store.business.currency)}',
      ),
    ));
  }

  Future<void> _share(BuildContext context, BizDoc d) async {
    final store = context.read<Store>();
    final watermark = !isPremium(context);
    final bytes = await withProgress(context, 'Creating PDF…', () => PdfService.document(store.business, d, watermark: watermark));
    if (bytes == null || !context.mounted) return;
    await FileActions.sharePdf(context, '${d.kind.label}_${d.number}', bytes,
        text: '${d.kind.label} ${d.number} — ${fmtMoney(d.total, store.business.currency)}');
    if (d.status == DocStatus.draft) {
      d.status = DocStatus.sent;
      await store.saveDoc(d);
    }
  }

  Future<void> _recordPayment(BuildContext context, BizDoc d) async {
    final store = context.read<Store>();
    final amount = TextEditingController(text: d.balance.toStringAsFixed(2));
    var method = 'Cash';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Record payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: InputDecoration(prefixText: '${store.business.currency} ', labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in const ['Cash', 'bKash', 'Nagad', 'Bank', 'Card', 'Cheque', 'UPI'])
                ChoiceChip(label: Text(m), selected: method == m, onSelected: (_) => set(() => method = m)),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save payment'))),
          ]),
        ),
      ),
    );
    final v = double.tryParse(amount.text) ?? 0;
    if (ok != true || v <= 0) return;
    d.payments.add(Payment(date: DateTime.now(), amount: v, method: method));
    if (d.status == DocStatus.draft) d.status = DocStatus.sent;
    await store.saveDoc(d);
    ReminderService.schedule(d, store.business.currency);
    if (!context.mounted) return;
    final receipt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment saved ✓'),
        content: const Text('Create a money receipt for this payment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create receipt')),
        ],
      ),
    );
    if (receipt != true || !context.mounted) return;
    final r = await store.convert(d, DocKind.receipt);
    r
      ..lines = []
      ..amountReceived = v
      ..paymentMethod = method;
    await store.saveDoc(r);
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocViewScreen(docId: r.id)));
    }
  }

  Future<void> _remind(BuildContext context, BizDoc d) async {
    final store = context.read<Store>();
    final b = store.business;
    final fallback = 'Dear ${d.client.name}, this is a friendly reminder that ${d.kind.label} ${d.number} '
        'of ${fmtMoney(d.balance, b.currency)} is due${d.dueDate == null ? '' : ' on ${dateFmt.format(d.dueDate!)}'}. '
        'Thank you! — ${b.name}';
    final lang = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Reminder message', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ListTile(leading: const Icon(Icons.short_text), title: const Text('Quick message'), onTap: () => Navigator.pop(ctx, '')),
          ListTile(leading: const Icon(Icons.auto_awesome), title: const Text('AI message (English)'), onTap: () => Navigator.pop(ctx, 'English')),
          ListTile(leading: const Icon(Icons.auto_awesome), title: const Text('AI message (Bangla)'), onTap: () => Navigator.pop(ctx, 'Bangla')),
        ]),
      ),
    );
    if (lang == null || !context.mounted) return;
    var msg = fallback;
    if (lang.isNotEmpty) {
      final ai = context.read<AiService>();
      msg = await withProgress(
            context,
            'Writing reminder…',
            () => ai.reminder(
              client: d.client.name,
              number: d.number,
              amount: fmtMoney(d.balance, b.currency),
              due: d.dueDate == null ? 'now' : dateFmt.format(d.dueDate!),
              company: b.name,
              language: lang,
            ),
          ) ??
          fallback;
    }
    final phone = d.client.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final wa = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(msg)}');
    if (phone.isNotEmpty && await launchUrl(wa, mode: LaunchMode.externalApplication)) return;
    await FileActions.shareText(msg);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final d = store.doc(docId);
    if (d == null) return const Scaffold(body: Center(child: Text('Not found')));
    final b = store.business;
    final status = d.liveStatus;

    Widget action(IconData icon, String label, VoidCallback onTap, {Color? color}) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: (color ?? AppColors.primary).withValues(alpha: 0.12),
                  child: Icon(icon, color: color ?? AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('${d.kind.label} ${d.number}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocEditorScreen(doc: d))),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'dup':
                  final c = d.copyAs(d.kind, store.newId(), store.nextNumber(d.kind));
                  await store.saveDoc(c);
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DocViewScreen(docId: c.id)));
                  }
                case 'cancel':
                  d.status = d.status == DocStatus.cancelled ? DocStatus.sent : DocStatus.cancelled;
                  await store.saveDoc(d);
                case 'delete':
                  if (await confirm(context, 'Delete ${d.number}?', 'This cannot be undone.')) {
                    await store.deleteDoc(d);
                    if (context.mounted) Navigator.pop(context);
                  }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'dup', child: Text('Duplicate')),
              PopupMenuItem(value: 'cancel', child: Text(d.status == DocStatus.cancelled ? 'Restore' : 'Mark cancelled')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(d.kind.icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(d.kind.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (d.kind == DocKind.invoice)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text(StatusChip.style(status).$1,
                      style: TextStyle(color: StatusChip.style(status).$2, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ]),
            const SizedBox(height: 12),
            Text(d.client.name.isEmpty ? '—' : d.client.name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(fmtMoney(d.kind.hasPrices ? d.total : 0, b.currency),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              [
                dateFmt.format(d.date),
                if (d.dueDate != null && d.kind.hasDueDate) 'Due ${dateFmt.format(d.dueDate!)}',
                if (d.kind == DocKind.invoice && d.paid > 0) 'Balance ${fmtMoney(d.balance, b.currency)}',
              ].join('  ·  '),
              style: const TextStyle(color: Colors.white70),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            // Top-aligned so 2-line labels don't push icons up.
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              action(Icons.visibility_outlined, 'Preview', () => _preview(context, d)),
              action(Icons.share_rounded, 'Share PDF', () => _share(context, d)),
              if (d.kind == DocKind.invoice && d.balance > 0)
                action(Icons.payments_outlined, 'Record\npayment', () => _recordPayment(context, d), color: AppColors.success),
              if (d.kind == DocKind.invoice && d.balance > 0)
                action(Icons.notifications_active_outlined, 'Remind', () => _remind(context, d), color: AppColors.warning),
              if (d.kind == DocKind.estimate)
                action(Icons.receipt_long_rounded, 'Make\ninvoice', () async {
                  final inv = await store.convert(d, DocKind.invoice);
                  if (context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocViewScreen(docId: inv.id)));
                  }
                }, color: AppColors.success),
              if (d.kind == DocKind.purchaseOrder || d.kind == DocKind.invoice)
                action(Icons.local_shipping_outlined, 'Challan', () async {
                  final c = await store.convert(d, DocKind.challan);
                  if (context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocViewScreen(docId: c.id)));
                  }
                }),
            ]),
          ),
        ),
        const AdBannerSlot(),
        if (d.lines.isNotEmpty) ...[
          SectionTitle('Items (${d.lines.length})'),
          Card(
            child: Column(children: [
              for (final l in d.lines)
                ListTile(
                  title: Text(l.name),
                  subtitle: Text('${l.qty % 1 == 0 ? l.qty.toInt() : l.qty} ${l.unit}'
                      '${d.kind.hasPrices ? ' × ${fmtMoney(l.price, b.currency)}' : ''}'),
                  trailing: d.kind.hasPrices ? Text(fmtMoney(l.amount, b.currency)) : null,
                ),
            ]),
          ),
        ],
        if (d.kind == DocKind.receipt && d.lines.isEmpty) ...[
          const SectionTitle('Receipt'),
          Card(
            child: Column(children: [
              ListTile(title: const Text('For'), trailing: Text(d.receivedFor.isEmpty ? '—' : d.receivedFor)),
              ListTile(title: const Text('Method'), trailing: Text(d.paymentMethod)),
              ListTile(title: const Text('In words'), subtitle: Text(PdfService.amountInWords(d.total, b.currency))),
            ]),
          ),
        ],
        if (d.payments.isNotEmpty) ...[
          const SectionTitle('Payments'),
          Card(
            child: Column(children: [
              for (final p in d.payments)
                ListTile(
                  leading: const Icon(Icons.check_circle, color: AppColors.success),
                  title: Text(fmtMoney(p.amount, b.currency)),
                  subtitle: Text('${dateFmt.format(p.date)} · ${p.method}'),
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Banner ad wrapped with spacing (hidden for Premium).
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key});
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.only(top: 10), child: Center(child: AdBanner()));
}
