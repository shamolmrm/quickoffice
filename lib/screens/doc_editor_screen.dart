import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/reminder_service.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'doc_view_screen.dart';

/// Create / edit any business document.
class DocEditorScreen extends StatefulWidget {
  const DocEditorScreen({super.key, required this.doc, this.isNew = false});
  final BizDoc doc;
  final bool isNew;
  @override
  State<DocEditorScreen> createState() => _DocEditorScreenState();
}

class _DocEditorScreenState extends State<DocEditorScreen> {
  late final BizDoc d = BizDoc.fromJson(widget.doc.toJson());
  late final _number = TextEditingController(text: d.number);
  late final _notes = TextEditingController(text: d.notes);
  late final _terms = TextEditingController(text: d.terms);
  late final _discount = TextEditingController(text: d.discount == 0 ? '' : _n(d.discount));
  late final _shipping = TextEditingController(text: d.shipping == 0 ? '' : _n(d.shipping));
  late final _received = TextEditingController(text: d.amountReceived == null ? '' : _n(d.amountReceived!));
  late final _for = TextEditingController(text: d.receivedFor);

  bool get _simpleReceipt => d.kind == DocKind.receipt && d.lines.isEmpty;
  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  String get cur => context.read<Store>().business.currency;

  Future<void> _pickDate({required bool due}) async {
    final init = due ? (d.dueDate ?? DateTime.now()) : d.date;
    final p = await showDatePicker(
        context: context, initialDate: init, firstDate: DateTime(2015), lastDate: DateTime(2100));
    if (p == null) return;
    setState(() => due ? d.dueDate = p : d.date = p);
  }

  Future<void> _pickClient() async {
    final c = await showModalBottomSheet<Client>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ClientPickerSheet(),
    );
    if (c != null) setState(() => d.client = c);
  }

  Future<void> _editLine([int? index]) async {
    final line = index == null ? Line(taxRate: context.read<Store>().business.taxRate) : Line.fromJson(d.lines[index].toJson());
    final r = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LineEditorSheet(line: line, currency: cur, showPrice: d.kind.hasPrices, canDelete: index != null),
    );
    if (r == null) return;
    setState(() {
      if (r == 'delete') {
        d.lines.removeAt(index!);
      } else if (index == null) {
        d.lines.add(r as Line);
      } else {
        d.lines[index] = r as Line;
      }
    });
  }

  Future<void> _aiFill() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = TextEditingController();
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('✨ Describe it — AI fills the form',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Bangla or English. Example:\n"Rahim Traders, 10 bosta cement 550 taka, 2 ton rod 85000, 5% discount"',
                style: TextStyle(color: ctx.cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, c.text),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Fill invoice'),
              ),
            ),
          ]),
        );
      },
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final store = context.read<Store>();
    final ai = context.read<AiService>();
    final j = await withProgress(context, 'AI is preparing the invoice…', () => ai.parseInvoice(text, cur));
    if (j == null || !mounted) return;
    setState(() {
      final c = Map<String, dynamic>.from(j['client'] ?? {});
      final name = (c['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        final existing = store.clients.where((x) => x.name.toLowerCase() == name.toLowerCase());
        d.client = existing.isNotEmpty
            ? existing.first.copy()
            : Client(
                id: store.newId(),
                name: name,
                company: (c['company'] ?? '').toString(),
                phone: (c['phone'] ?? '').toString(),
                address: (c['address'] ?? '').toString(),
              );
      }
      for (final it in (j['items'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(it);
        d.lines.add(Line(
          name: (m['name'] ?? '').toString(),
          qty: (m['qty'] as num?)?.toDouble() ?? 1,
          unit: (m['unit'] ?? 'pcs').toString(),
          price: (m['price'] as num?)?.toDouble() ?? 0,
          taxRate: store.business.taxRate,
        ));
      }
      final disc = (j['discount'] as num?)?.toDouble() ?? 0;
      if (disc > 0) {
        d.discount = disc;
        _discount.text = _n(disc);
      }
      final notes = (j['notes'] ?? '').toString();
      if (notes.isNotEmpty) _notes.text = notes;
    });
  }

  Future<void> _save() async {
    final store = context.read<Store>();
    if (d.client.name.trim().isEmpty && d.kind != DocKind.challan) {
      return context.toast('Add a ${d.kind.partyLabel.toLowerCase()} first');
    }
    if (_simpleReceipt && (double.tryParse(_received.text) ?? 0) <= 0) {
      return context.toast('Enter the amount received');
    }
    if (!_simpleReceipt && d.lines.isEmpty) return context.toast('Add at least one item');
    d
      ..number = _number.text.trim().isEmpty ? d.number : _number.text.trim()
      ..notes = _notes.text.trim()
      ..terms = _terms.text.trim()
      ..discount = double.tryParse(_discount.text) ?? 0
      ..shipping = double.tryParse(_shipping.text) ?? 0
      ..amountReceived = double.tryParse(_received.text)
      ..receivedFor = _for.text.trim();
    if (d.status == DocStatus.draft) d.status = d.kind == DocKind.receipt ? DocStatus.paid : DocStatus.sent;
    // Remember the client and items for next time.
    if (d.client.name.trim().isNotEmpty) {
      if (d.client.id.isEmpty) d.client = Client.fromJson(d.client.toJson()..['id'] = store.newId());
      await store.upsertClient(d.client.copy());
    }
    await store.learnItems(d.lines);
    await store.saveDoc(d);
    ReminderService.schedule(d, store.business.currency);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DocViewScreen(docId: d.id)));
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<Store>().business;
    d.discount = double.tryParse(_discount.text) ?? 0;
    d.shipping = double.tryParse(_shipping.text) ?? 0;
    d.amountReceived = double.tryParse(_received.text);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.isNew ? 'New' : 'Edit'} ${d.kind.label}'),
        actions: [
          if (d.kind.hasPrices)
            TextButton.icon(
              onPressed: _aiFill,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('AI fill'),
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              TextField(
                controller: _number,
                decoration: InputDecoration(labelText: '${d.kind.label} number', prefixIcon: const Icon(Icons.tag)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _dateTile('Date', d.date, () => _pickDate(due: false))),
                if (d.kind.hasDueDate) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _dateTile('Due date', d.dueDate, () => _pickDate(due: true))),
                ],
              ]),
              if (d.kind.hasDueDate)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 6, children: [
                    for (final days in [0, 7, 15, 30])
                      ActionChip(
                        label: Text(days == 0 ? 'On receipt' : '$days days'),
                        onPressed: () => setState(() => d.dueDate = d.date.add(Duration(days: days))),
                      ),
                  ]),
                ),
            ]),
          ),
        ),
        SectionTitle(d.kind.partyLabel),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.person_outline, color: AppColors.primary),
            ),
            title: Text(d.client.name.isEmpty ? 'Choose or add ${d.kind.partyLabel.toLowerCase()}' : d.client.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: d.client.name.isEmpty
                ? null
                : Text([d.client.company, d.client.phone].where((e) => e.isNotEmpty).join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickClient,
          ),
        ),
        if (d.kind == DocKind.receipt) ...[
          const SectionTitle('Payment'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (d.lines.isEmpty)
                  TextField(
                    controller: _received,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(labelText: 'Amount received', prefixText: '${b.currency} '),
                  ),
                const SizedBox(height: 10),
                TextField(controller: _for, decoration: const InputDecoration(labelText: 'Received for (e.g. Invoice INV-0003, advance)')),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final m in const ['Cash', 'bKash', 'Nagad', 'Bank', 'Card', 'Cheque', 'UPI'])
                    ChoiceChip(
                      label: Text(m),
                      selected: d.paymentMethod == m,
                      onSelected: (_) => setState(() => d.paymentMethod = m),
                    ),
                ]),
              ]),
            ),
          ),
        ],
        if (!_simpleReceipt || d.kind != DocKind.receipt) ...[
          SectionTitle('Items (${d.lines.length})',
              trailing: TextButton.icon(
                  onPressed: () => _editLine(), icon: const Icon(Icons.add), label: const Text('Add item'))),
          if (d.lines.isEmpty)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
              onPressed: () => _editLine(),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add your first item'),
            ),
          for (var i = 0; i < d.lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  onTap: () => _editLine(i),
                  title: Text(d.lines[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(d.kind.hasPrices
                      ? '${_n(d.lines[i].qty)} ${d.lines[i].unit} × ${fmtMoney(d.lines[i].price, b.currency)}'
                          '${d.lines[i].taxRate > 0 ? ' + ${_n(d.lines[i].taxRate)}% tax' : ''}'
                      : '${_n(d.lines[i].qty)} ${d.lines[i].unit}'),
                  trailing: d.kind.hasPrices
                      ? Text(fmtMoney(d.lines[i].amount, b.currency), style: const TextStyle(fontWeight: FontWeight.w700))
                      : null,
                ),
              ),
            ),
        ],
        if (d.kind == DocKind.receipt && _simpleReceipt)
          TextButton.icon(
            onPressed: () => _editLine(),
            icon: const Icon(Icons.list_alt),
            label: const Text('Add item list instead (optional)'),
          ),
        if (d.kind.hasPrices && !_simpleReceipt) ...[
          const SectionTitle('Adjustments'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _discount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Discount'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text(b.currency)),
                      const ButtonSegment(value: true, label: Text('%')),
                    ],
                    selected: {d.discountIsPercent},
                    onSelectionChanged: (v) => setState(() => d.discountIsPercent = v.first),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: _shipping,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: 'Shipping / delivery charge', prefixText: '${b.currency} '),
                ),
              ]),
            ),
          ),
        ],
        const SectionTitle('Notes & terms'),
        TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (shown on PDF)')),
        const SizedBox(height: 10),
        TextField(controller: _terms, maxLines: 3, decoration: const InputDecoration(labelText: 'Terms & conditions')),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: context.cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
          ),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total', style: TextStyle(color: context.cs.onSurfaceVariant)),
                Text(d.kind.hasPrices ? fmtMoney(d.total, b.currency) : '${d.lines.length} items',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
            ),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save & preview'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.event_outlined)),
          child: Text(date == null ? '—' : dateFmt.format(date)),
        ),
      );
}

/// Pick a saved client or create a new one.
class ClientPickerSheet extends StatefulWidget {
  const ClientPickerSheet({super.key});
  @override
  State<ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<ClientPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final list = store.clients
        .where((c) => '${c.name} ${c.company} ${c.phone}'.toLowerCase().contains(_q.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (_, sc) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(hintText: 'Search clients…', prefixIcon: Icon(Icons.search), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () async {
                final c = await editClient(context, Client(id: store.newId(), name: _q));
                if (c != null && context.mounted) Navigator.pop(context, c);
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('New'),
            ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.people_outline, title: 'No clients yet', message: 'Tap New to add one.')
              : ListView.builder(
                  controller: sc,
                  itemCount: list.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: CircleAvatar(child: Text(list[i].name.isEmpty ? '?' : list[i].name[0].toUpperCase())),
                    title: Text(list[i].name),
                    subtitle: Text([list[i].company, list[i].phone].where((e) => e.isNotEmpty).join(' · ')),
                    onTap: () => Navigator.pop(context, list[i].copy()),
                  ),
                ),
        ),
      ]),
    );
  }
}

/// Add / edit client form; saves to the store and returns it.
Future<Client?> editClient(BuildContext context, Client c) {
  final name = TextEditingController(text: c.name);
  final company = TextEditingController(text: c.company);
  final phone = TextEditingController(text: c.phone);
  final email = TextEditingController(text: c.email);
  final address = TextEditingController(text: c.address);
  return showModalBottomSheet<Client>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: name, autofocus: c.name.isEmpty, decoration: const InputDecoration(labelText: 'Name *')),
          const SizedBox(height: 10),
          TextField(controller: company, decoration: const InputDecoration(labelText: 'Company')),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone / WhatsApp')),
          const SizedBox(height: 10),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                c
                  ..name = name.text.trim()
                  ..company = company.text.trim()
                  ..phone = phone.text.trim()
                  ..email = email.text.trim()
                  ..address = address.text.trim();
                await ctx.read<Store>().upsertClient(c);
                if (ctx.mounted) Navigator.pop(ctx, c);
              },
              child: const Text('Save client'),
            ),
          ),
        ]),
      ),
    ),
  );
}

/// Edit one line item, with catalog suggestions.
class LineEditorSheet extends StatefulWidget {
  const LineEditorSheet({super.key, required this.line, required this.currency, required this.showPrice, this.canDelete = false});
  final Line line;
  final String currency;
  final bool showPrice, canDelete;
  @override
  State<LineEditorSheet> createState() => _LineEditorSheetState();
}

class _LineEditorSheetState extends State<LineEditorSheet> {
  late final _desc = TextEditingController(text: widget.line.description);
  late final _qty = TextEditingController(text: _fmt(widget.line.qty));
  late final _unit = TextEditingController(text: widget.line.unit);
  late final _price = TextEditingController(text: widget.line.price == 0 ? '' : _fmt(widget.line.price));
  late final _tax = TextEditingController(text: widget.line.taxRate == 0 ? '' : _fmt(widget.line.taxRate));
  late String _name = widget.line.name;

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final items = context.read<Store>().items;
    final amount = (double.tryParse(_qty.text) ?? 0) * (double.tryParse(_price.text) ?? 0);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Autocomplete<Item>(
            initialValue: TextEditingValue(text: _name),
            optionsBuilder: (v) => v.text.isEmpty
                ? const Iterable<Item>.empty()
                : items.where((i) => i.name.toLowerCase().contains(v.text.toLowerCase())),
            displayStringForOption: (i) => i.name,
            onSelected: (i) => setState(() {
              _name = i.name;
              _unit.text = i.unit;
              _price.text = _fmt(i.price);
              if (i.taxRate > 0) _tax.text = _fmt(i.taxRate);
            }),
            fieldViewBuilder: (ctx, c, focus, _) => TextField(
              controller: c,
              focusNode: focus,
              autofocus: _name.isEmpty,
              onChanged: (v) => _name = v,
              decoration: const InputDecoration(labelText: 'Item / service name *', helperText: 'Saved items appear as you type'),
            ),
          ),
          const SizedBox(height: 10),
          TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Qty'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'))),
          ]),
          Wrap(spacing: 6, children: [
            for (final u in const ['pcs', 'kg', 'box', 'bag', 'hour', 'day', 'month', 'set', 'ft', 'm'])
              ActionChip(visualDensity: VisualDensity.compact, label: Text(u), onPressed: () => setState(() => _unit.text = u)),
          ]),
          if (widget.showPrice) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: 'Rate', prefixText: '${widget.currency} '),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _tax,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tax %'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text('Amount: ${fmtMoney(amount, widget.currency)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            if (widget.canDelete)
              IconButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (_name.trim().isEmpty) return;
                  Navigator.pop(
                    context,
                    Line(
                      name: _name.trim(),
                      description: _desc.text.trim(),
                      qty: double.tryParse(_qty.text) ?? 1,
                      unit: _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
                      price: double.tryParse(_price.text) ?? 0,
                      taxRate: double.tryParse(_tax.text) ?? 0,
                    ),
                  );
                },
                child: const Text('Done'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
