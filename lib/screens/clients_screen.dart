import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'doc_editor_screen.dart';
import 'home_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final cur = store.business.currency;
    final list = store.clients
        .where((c) => '${c.name} ${c.company} ${c.phone}'.toLowerCase().contains(_q.toLowerCase()))
        .toList()
      ..sort((a, b) => store.clientBalance(b).compareTo(store.clientBalance(a)));
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () => editClient(context, Client(id: store.newId())),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add client'),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(hintText: 'Search clients…', prefixIcon: Icon(Icons.search), isDense: true),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No clients yet',
                  message: 'Clients are saved automatically when you make an invoice.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final due = store.clientBalance(c);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                          ),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text([c.company, c.phone].where((e) => e.isNotEmpty).join(' · ')),
                          trailing: due > 0
                              ? Text(fmtMoney(due, cur), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))
                              : const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientDetailScreen(clientId: c.id))),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({super.key, required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final c = store.clients.where((x) => x.id == clientId).firstOrNull;
    if (c == null) return const Scaffold();
    final docs = store.docs.where((d) => d.client.id == c.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    final billed = docs.where((d) => d.kind == DocKind.invoice).fold<double>(0, (s, d) => s + d.total);
    final cur = store.business.currency;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editClient(context, c)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirm(context, 'Delete ${c.name}?', 'Their documents are kept.')) {
                await store.deleteClient(c);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (c.company.isNotEmpty) Text(c.company, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (c.address.isNotEmpty) Text(c.address),
              const SizedBox(height: 10),
              Row(children: [
                if (c.phone.isNotEmpty) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => launchUrl(Uri.parse('tel:${c.phone}')),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => launchUrl(Uri.parse('https://wa.me/${c.phone.replaceAll(RegExp(r'[^0-9]'), '')}'),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                  ),
                ],
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _box(context, 'Total billed', fmtMoney(billed, cur), AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(child: _box(context, 'Balance due', fmtMoney(store.clientBalance(c), cur), AppColors.danger)),
        ]),
        SectionTitle('Documents (${docs.length})',
            trailing: TextButton.icon(
              onPressed: () {
                final d = store.newDoc(DocKind.invoice)..client = c.copy();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocEditorScreen(doc: d, isNew: true)));
              },
              icon: const Icon(Icons.add),
              label: const Text('Invoice'),
            )),
        for (final d in docs) DocTile(doc: d),
      ]),
    );
  }

  Widget _box(BuildContext context, String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: context.cs.onSurfaceVariant)),
          FittedBox(child: Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800))),
        ]),
      );
}

/// Saved products / services catalog.
class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key});

  Future<void> _edit(BuildContext context, Item it) async {
    final store = context.read<Store>();
    final name = TextEditingController(text: it.name);
    final unit = TextEditingController(text: it.unit);
    final price = TextEditingController(text: it.price == 0 ? '' : '${it.price}');
    final tax = TextEditingController(text: it.taxRate == 0 ? '' : '${it.taxRate}');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: name, autofocus: it.name.isEmpty, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Price', prefixText: '${store.business.currency} '))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: tax, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tax %'))),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))),
        ]),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    it
      ..name = name.text.trim()
      ..unit = unit.text.trim().isEmpty ? 'pcs' : unit.text.trim()
      ..price = double.tryParse(price.text) ?? 0
      ..taxRate = double.tryParse(tax.text) ?? 0;
    await store.upsertItem(it);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final items = [...store.items]..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('Products & services')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, Item(id: store.newId())),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No items yet',
              message: 'Items you use in invoices are saved here automatically.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: items.length,
              itemBuilder: (_, i) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(items[i].name),
                  subtitle: Text('per ${items[i].unit}${items[i].taxRate > 0 ? ' · ${items[i].taxRate}% tax' : ''}'),
                  trailing: Text(fmtMoney(items[i].price, store.business.currency), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => _edit(context, items[i]),
                  onLongPress: () async {
                    if (await confirm(context, 'Delete ${items[i].name}?', '')) store.deleteItem(items[i]);
                  },
                ),
              ),
            ),
    );
  }
}
