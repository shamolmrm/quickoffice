import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _year = DateTime.now().year;

  Future<void> _exportCsv(Store store) async {
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final rows = [
      'Type,Number,Date,Client,Total,Paid,Balance,Status',
      for (final d in store.byKind(null).where((d) => d.date.year == _year))
        [
          d.kind.label,
          d.number,
          DateFormat('yyyy-MM-dd').format(d.date),
          q(d.client.name),
          d.total.toStringAsFixed(2),
          d.paid.toStringAsFixed(2),
          d.balance.toStringAsFixed(2),
          StatusChip.style(d.liveStatus).$1,
        ].join(','),
    ];
    final bytes = Uint8List.fromList(utf8.encode('﻿${rows.join('\n')}'));
    final f = await store.export('QuickOffice_$_year.csv', bytes);
    if (mounted) FileActions.shareFile(context, f.path, text: 'Business report $_year');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final cur = store.business.currency;
    final yearInv = store.invoices.where((d) => d.date.year == _year);
    final invoiced = yearInv.fold<double>(0, (s, d) => s + d.total);
    var received = 0.0;
    for (var m = 1; m <= 12; m++) {
      received += store.receivedIn(_year, m);
    }
    final byClient = <String, double>{};
    for (final d in yearInv) {
      byClient.update(d.client.name, (v) => v + d.total, ifAbsent: () => d.total);
    }
    final top = byClient.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final unpaid = store.invoices.where((d) => d.balance > 0).toList()..sort((a, b) => b.balance.compareTo(a.balance));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(tooltip: 'Export Excel (CSV)', icon: const Icon(Icons.file_download_outlined), onPressed: () => _exportCsv(store)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => _year--), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Center(child: Text('$_year', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)))),
          IconButton(
              onPressed: _year >= DateTime.now().year ? null : () => setState(() => _year++),
              icon: const Icon(Icons.chevron_right)),
        ]),
        Row(children: [
          Expanded(child: _tile('Invoiced', fmtMoney(invoiced, cur), AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(child: _tile('Received', fmtMoney(received, cur), AppColors.success)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _tile('Unpaid now', fmtMoney(store.totalUnpaid, cur), AppColors.danger)),
          const SizedBox(width: 10),
          Expanded(child: _tile('Invoices', '${yearInv.length}', const Color(0xFF6366F1))),
        ]),
        const SectionTitle('Money received — last 12 months'),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: RevenueChart(months: 12, store: store))),
        if (top.isNotEmpty) ...[
          const SectionTitle('Top clients'),
          Card(
            child: Column(children: [
              for (final e in top.take(5))
                ListTile(
                  leading: const Icon(Icons.emoji_events_outlined, color: Colors.amber),
                  title: Text(e.key.isEmpty ? '—' : e.key),
                  trailing: Text(fmtMoney(e.value, cur), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ],
        if (unpaid.isNotEmpty) ...[
          const SectionTitle('Who owes you'),
          for (final d in unpaid.take(10)) DocTile(doc: d),
        ],
        if (store.docs.where((d) => d.kind == DocKind.receipt).isNotEmpty) const SizedBox(height: 40),
      ]),
    );
  }

  Widget _tile(String label, String value, Color c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: context.cs.onSurfaceVariant)),
          FittedBox(child: Text(value, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w800))),
        ]),
      );
}
