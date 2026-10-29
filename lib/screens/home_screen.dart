import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/ad_gate.dart';
import '../services/premium_service.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cv_screen.dart';
import 'doc_editor_screen.dart';
import 'doc_view_screen.dart';
import 'letter_screen.dart';
import 'premium_screen.dart';
import 'reports_screen.dart';
import 'seal_screen.dart';

void newDocument(BuildContext context, DocKind k) {
  final store = context.read<Store>();
  AdGate.maybeInterstitial();
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocEditorScreen(doc: store.newDoc(k), isNew: true)));
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final b = store.business;
    final now = DateTime.now();
    final received = store.receivedIn(now.year, now.month);
    final invoiced = store.invoicedIn(now.year, now.month);
    final overdue = store.overdue;
    final recent = store.byKind(null).take(6).toList();
    final premium = context.watch<PremiumService>().isPremium;

    final actions = [
      (Icons.receipt_long_rounded, 'Invoice', const Color(0xFF0E9F6E), () => newDocument(context, DocKind.invoice)),
      (Icons.request_quote_rounded, 'Quotation', const Color(0xFF0EA5E9), () => newDocument(context, DocKind.estimate)),
      (Icons.payments_rounded, 'Money\nReceipt', const Color(0xFFF59E0B), () => newDocument(context, DocKind.receipt)),
      (Icons.mail_rounded, 'AI Letter', const Color(0xFF6366F1),
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LetterListScreen()))),
      (Icons.verified_rounded, 'Seal\nMaker', const Color(0xFFEF4444),
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SealScreen()))),
      (Icons.badge_rounded, 'CV Maker', const Color(0xFFEC4899),
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CvScreen()))),
      (Icons.shopping_cart_checkout_rounded, 'Purchase\nOrder', const Color(0xFF8B5CF6),
          () => newDocument(context, DocKind.purchaseOrder)),
      (Icons.local_shipping_rounded, 'Delivery\nChallan', const Color(0xFF14B8A6),
          () => newDocument(context, DocKind.challan)),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          Row(children: [
            const AppLogo(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting(), style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 13)),
                Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
            ),
            if (!premium)
              IconButton(
                tooltip: 'Go Premium',
                icon: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen())),
              ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Received in ${DateFormat('MMMM').format(now)}', style: const TextStyle(color: Colors.white70)),
              Text(fmtMoney(received, b.currency),
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                _stat('Invoiced', fmtMoney(invoiced, b.currency)),
                _stat('Unpaid', fmtMoney(store.totalUnpaid, b.currency)),
                _stat('Overdue', '${overdue.length}'),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            childAspectRatio: 0.82,
            children: [
              for (final a in actions)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: a.$4,
                  // Top-aligned so 1- and 2-line labels keep icons in a row.
                  child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: a.$3.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                      child: Icon(a.$1, color: a.$3),
                    ),
                    const SizedBox(height: 6),
                    Text(a.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ],
          ),
          const Center(child: AdBanner()),
          if (overdue.isNotEmpty) ...[
            SectionTitle('⚠️ Overdue (${overdue.length})'),
            for (final d in overdue.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  child: ListTile(
                    title: Text(d.client.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${d.number} · due ${dateFmt.format(d.dueDate!)}'),
                    trailing: Text(fmtMoney(d.balance, b.currency),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocViewScreen(docId: d.id))),
                  ),
                ),
              ),
          ],
          SectionTitle('Last 6 months',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportsScreen())),
                child: const Text('Reports'),
              )),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: RevenueChart(months: 6, store: store))),
          SectionTitle('Recent'),
          if (recent.isEmpty)
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Create your first invoice',
              message: 'Professional PDF in under a minute. Share on WhatsApp instantly.',
              action: FilledButton.icon(
                onPressed: () => newDocument(context, DocKind.invoice),
                icon: const Icon(Icons.add),
                label: const Text('New invoice'),
              ),
            )
          else
            for (final d in recent) DocTile(doc: d),
        ]),
      ),
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning ☀️' : h < 17 ? 'Good afternoon 👋' : 'Good evening 🌙';
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
      );
}

class DocTile extends StatelessWidget {
  const DocTile({super.key, required this.doc});
  final BizDoc doc;

  @override
  Widget build(BuildContext context) {
    final cur = context.read<Store>().business.currency;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocViewScreen(docId: doc.id))),
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Icon(doc.kind.icon, color: AppColors.primary, size: 20),
          ),
          title: Text(doc.client.name.isEmpty ? doc.kind.label : doc.client.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${doc.number} · ${dateFmt.format(doc.date)}'),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (doc.kind.hasPrices)
              Text(fmtMoney(doc.total, cur), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            if (doc.kind == DocKind.invoice) StatusChip(doc.liveStatus) else Text(doc.kind.label, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

/// Simple bar chart of money received per month.
class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key, required this.months, required this.store});
  final int months;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final data = [
      for (var i = months - 1; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i);
          return (DateFormat('MMM').format(m), store.receivedIn(m.year, m.month));
        }()
    ];
    final max = data.fold<double>(0, (s, e) => e.$2 > s ? e.$2 : s);
    return SizedBox(
      height: 150,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final e in data)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (e.$2 > 0)
                FittedBox(
                  child: Text(NumberFormat.compact().format(e.$2),
                      style: TextStyle(fontSize: 10, color: context.cs.onSurfaceVariant)),
                ),
              const SizedBox(height: 4),
              Container(
                height: max == 0 ? 4 : 4 + 100 * e.$2 / max,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF14B8A6), Color(0xFF0E9F6E)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text(e.$1, style: const TextStyle(fontSize: 11)),
            ]),
          ),
      ]),
    );
  }
}
