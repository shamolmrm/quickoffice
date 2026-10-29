import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});
  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  DocKind? _kind;
  DocStatus? _status;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final cur = store.business.currency;
    final docs = store.byKind(_kind).where((d) {
      if (_status != null && d.liveStatus != _status) return false;
      final q = _q.toLowerCase();
      return q.isEmpty ||
          d.number.toLowerCase().contains(q) ||
          d.client.name.toLowerCase().contains(q) ||
          d.lines.any((l) => l.name.toLowerCase().contains(q));
    }).toList();
    final total = docs.where((d) => d.kind.hasPrices).fold<double>(0, (s, d) => s + d.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
                hintText: 'Search number, client or item…', prefixIcon: Icon(Icons.search), isDense: true),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            _chip('All', _kind == null, () => setState(() => _kind = null)),
            for (final k in DocKind.values) _chip(k.label, _kind == k, () => setState(() => _kind = k)),
          ]),
        ),
        if (_kind == DocKind.invoice || _kind == null)
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              for (final s in [null, DocStatus.sent, DocStatus.partial, DocStatus.overdue, DocStatus.paid])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(s == null ? 'Any status' : StatusChip.style(s).$1),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
                ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Row(children: [
            Text('${docs.length} documents', style: TextStyle(color: context.cs.onSurfaceVariant)),
            const Spacer(),
            Text(fmtMoney(total, cur), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(
          child: docs.isEmpty
              ? const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing here yet', message: 'Tap + to create a document.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => DocTile(doc: docs[i]),
                ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
        child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => onTap()),
      );
}
