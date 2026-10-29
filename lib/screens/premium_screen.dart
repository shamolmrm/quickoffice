import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/env.dart';
import '../services/premium_service.dart';
import '../theme.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const _perks = [
    (Icons.block_rounded, 'No ads, no watermark', 'Clean, professional PDFs'),
    (Icons.auto_awesome, 'Unlimited AI', 'AI invoices, letters, reminders, CV'),
    (Icons.receipt_long_rounded, 'Unlimited documents', 'Invoice, quotation, receipt, PO, challan'),
    (Icons.palette_rounded, 'All designs & brand colour', 'Logo, signature & seal on every page'),
    (Icons.insights_rounded, 'Reports & Excel export', 'Sales, dues, top clients'),
    (Icons.notifications_active_rounded, 'Payment reminders', 'Never miss a due date'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PremiumService>();
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 230,
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF3A2BB8),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: AppColors.aiGradient),
              child: SafeArea(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 30),
                  const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 64),
                  const SizedBox(height: 10),
                  Text(p.isPremium ? 'You are Premium 👑' : 'QuickOffice Premium',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Everything unlocked. No ads.',
                      style: TextStyle(color: Colors.white70)),
                ]),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(children: [
            for (final perk in _perks)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(perk.$1, color: AppColors.primary),
                ),
                title: Text(perk.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(perk.$3),
                trailing: const Icon(Icons.check_circle, color: AppColors.success),
              ),
            const SizedBox(height: 16),
            if (p.isPremium)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.verified, color: AppColors.success),
                  title: Text('Premium is active on this device'),
                ),
              )
            else if (!p.storeAvailable || p.products.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    p.storeAvailable
                        ? 'Premium plans are being set up on Google Play. Please try again later.'
                        : 'Google Play is not available on this device.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final prod in p.products)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlanCard(
                    title: prod.id == Env.premiumLifetimeId ? 'Lifetime' : 'Monthly',
                    price: prod.price,
                    note: prod.id == Env.premiumLifetimeId
                        ? 'Pay once, use forever'
                        : 'Cancel anytime',
                    best: prod.id == Env.premiumLifetimeId,
                    busy: p.busy,
                    onTap: () => p.buy(prod),
                  ),
                ),
            if (p.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(p.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger)),
              ),
            if (!Env.isProBuild)
              TextButton(
                onPressed: p.busy ? null : p.restore,
                child: const Text('Restore purchase'),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.note,
    required this.best,
    required this.busy,
    required this.onTap,
  });
  final String title, price, note;
  final bool best, busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: best ? AppColors.primary : context.cs.outlineVariant,
              width: best ? 2.5 : 1),
          color: best ? AppColors.primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (best) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                    child: const Text('BEST VALUE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              Text(note, style: TextStyle(color: context.cs.onSurfaceVariant)),
            ]),
          ),
          busy
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(price,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
