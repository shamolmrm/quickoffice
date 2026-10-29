import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'clients_screen.dart';
import 'docs_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  void _newSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Create new', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final k in DocKind.values)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(k.icon, color: AppColors.primary),
              ),
              title: Text(k.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                newDocument(context, k);
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), DocsScreen(), ClientsScreen(), MoreScreen()];
    Widget item(IconData icon, String label, int i) {
      final on = _tab == i;
      final c = on ? AppColors.primary : context.cs.onSurfaceVariant;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _tab = i),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: c),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(children: [
              item(Icons.dashboard_rounded, 'Home', 0),
              item(Icons.description_rounded, 'Documents', 1),
              Expanded(
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _newSheet,
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
              item(Icons.people_alt_rounded, 'Clients', 2),
              item(Icons.grid_view_rounded, 'More', 3),
            ]),
          ),
        ),
      ),
    );
  }
}
