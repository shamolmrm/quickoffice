import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ad_gate.dart';
import '../services/env.dart';
import '../services/premium_service.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'business_screen.dart';
import 'clients_screen.dart';
import 'cv_screen.dart';
import 'letter_screen.dart';
import 'premium_screen.dart';
import 'reports_screen.dart';
import 'seal_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final premium = context.watch<PremiumService>().isPremium;
    void go(Widget w) {
      AdGate.maybeInterstitial();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    }

    final tools = [
      (Icons.mail_rounded, 'AI Letters', 'Appointment, NOC, salary…', const Color(0xFF6366F1), () => go(const LetterListScreen())),
      (Icons.verified_rounded, 'Seal Maker', 'Round & square stamps', const Color(0xFFEF4444), () => go(const SealScreen())),
      (Icons.badge_rounded, 'CV Maker', 'Pro resume with photo', const Color(0xFFEC4899), () => go(const CvScreen())),
      (Icons.insights_rounded, 'Reports', 'Sales, dues, Excel', const Color(0xFF0EA5E9), () => go(const ReportsScreen())),
      (Icons.inventory_2_rounded, 'Products', 'Saved items & prices', const Color(0xFFF59E0B), () => go(const ItemsScreen())),
      (Icons.store_rounded, 'Business', 'Logo, sign, payment', const Color(0xFF0E9F6E), () => go(const BusinessScreen())),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => go(const PremiumScreen()),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(premium ? 'Premium active 👑' : 'Go Premium',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(premium ? 'No ads · no watermark · unlimited AI' : 'Remove watermark & ads, unlimited AI',
                      style: const TextStyle(color: Colors.white)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            for (final t in tools)
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: t.$5,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: t.$4.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                        child: Icon(t.$1, color: t.$4),
                      ),
                      const Spacer(),
                      Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(t.$3, style: TextStyle(fontSize: 11.5, color: context.cs.onSurfaceVariant)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Center(child: AdBanner()),
        const SectionTitle('Settings'),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Theme'),
              trailing: DropdownButton<ThemeMode>(
                value: s.themeMode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
                onChanged: (m) => s.setThemeMode(m!),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('AI engine'),
              subtitle: Text(s.hasOwnKey ? 'Your Gemini key' : (Env.hasBuiltInKey ? 'Built in' : 'Add a Gemini key')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final k = await promptText(context, 'Gemini API key (optional)', initial: s.apiKey, hint: 'Paste key');
                if (k != null) s.setApiKey(k);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_outline_rounded),
              title: const Text('Rate us'),
              onTap: () => launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.quickoffice.pro'),
                  mode: LaunchMode.externalApplication),
            ),
            const ListTile(leading: Icon(Icons.info_outline), title: Text('Version'), trailing: Text('1.0.0')),
          ]),
        ),
      ]),
    );
  }
}
