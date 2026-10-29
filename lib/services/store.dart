import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

/// All business data, persisted as one JSON file in app storage.
class Store extends ChangeNotifier {
  final _uuid = const Uuid();
  late Directory root;
  late File _db;

  Business business = Business();
  final List<Client> clients = [];
  final List<Item> items = [];
  final List<BizDoc> docs = [];
  final List<Letter> letters = [];
  final Map<String, int> _counters = {};

  String newId() => _uuid.v4();

  Future<void> load() async {
    final base = await getApplicationDocumentsDirectory();
    root = Directory('${base.path}/quickoffice');
    await Directory('${root.path}/media').create(recursive: true);
    await Directory('${root.path}/exports').create(recursive: true);
    _db = File('${root.path}/data.json');
    if (!await _db.exists()) return;
    try {
      final j = jsonDecode(await _db.readAsString()) as Map<String, dynamic>;
      business = Business.fromJson(Map<String, dynamic>.from(j['business'] ?? {}));
      // Parse entries one by one so a bad record never hides the rest.
      void each(String key, void Function(Map<String, dynamic>) add) {
        for (final e in (j[key] as List? ?? [])) {
          try {
            add(Map<String, dynamic>.from(e));
          } catch (err) {
            debugPrint('skip $key entry: $err');
          }
        }
      }

      each('clients', (e) => clients.add(Client.fromJson(e)));
      each('items', (e) => items.add(Item.fromJson(e)));
      each('docs', (e) => docs.add(BizDoc.fromJson(e)));
      each('letters', (e) => letters.add(Letter.fromJson(e)));
      _counters.addAll(Map<String, int>.from(j['counters'] ?? {}));
    } catch (e) {
      debugPrint('data load failed: $e');
      await _db.copy('${root.path}/data_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    }
  }

  Future<void> save() async {
    notifyListeners();
    await _db.writeAsString(jsonEncode({
      'business': business.toJson(),
      'clients': [for (final c in clients) c.toJson()],
      'items': [for (final i in items) i.toJson()],
      'docs': [for (final d in docs) d.toJson()],
      'letters': [for (final l in letters) l.toJson()],
      'counters': _counters,
    }));
  }

  // ───────── documents ─────────

  String nextNumber(DocKind k) {
    final n = (_counters[k.name] ?? 0) + 1;
    return '${k.prefix}-${n.toString().padLeft(4, '0')}';
  }

  BizDoc newDoc(DocKind k) => BizDoc(
        id: newId(),
        kind: k,
        number: nextNumber(k),
        date: DateTime.now(),
        dueDate: k.hasDueDate ? DateTime.now().add(const Duration(days: 7)) : null,
        terms: business.terms,
      );

  Future<void> saveDoc(BizDoc d) async {
    final i = docs.indexWhere((x) => x.id == d.id);
    if (i < 0) {
      docs.add(d);
      // Advance the counter only when a new number is actually used.
      final m = RegExp(r'(\d+)$').firstMatch(d.number);
      final n = int.tryParse(m?[1] ?? '') ?? 0;
      if (n > (_counters[d.kind.name] ?? 0)) _counters[d.kind.name] = n;
    } else {
      docs[i] = d;
    }
    await save();
  }

  Future<void> deleteDoc(BizDoc d) async {
    docs.removeWhere((x) => x.id == d.id);
    await save();
  }

  BizDoc? doc(String id) {
    for (final d in docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<BizDoc> byKind(DocKind? k) =>
      (k == null ? [...docs] : docs.where((d) => d.kind == k).toList())
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Estimate → Invoice, Invoice → Receipt etc.
  Future<BizDoc> convert(BizDoc from, DocKind to) async {
    final d = from.copyAs(to, newId(), nextNumber(to));
    if (to.hasDueDate) d.dueDate = DateTime.now().add(const Duration(days: 7));
    if (to == DocKind.receipt) {
      d.amountReceived = from.balance > 0 ? from.balance : from.total;
      d.receivedFor = '${from.kind.label} ${from.number}';
      d.status = DocStatus.paid;
    }
    await saveDoc(d);
    return d;
  }

  // ───────── dashboard numbers ─────────

  Iterable<BizDoc> get invoices =>
      docs.where((d) => d.kind == DocKind.invoice && d.status != DocStatus.cancelled && d.status != DocStatus.draft);

  double get totalUnpaid => invoices.fold(0, (s, d) => s + d.balance);
  List<BizDoc> get overdue => invoices.where((d) => d.liveStatus == DocStatus.overdue).toList()
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

  /// Money actually received in a month (payments + money receipts).
  double receivedIn(int year, int month) {
    var sum = 0.0;
    for (final d in docs) {
      if (d.kind == DocKind.receipt) {
        if (d.date.year == year && d.date.month == month) sum += d.total;
      } else if (d.kind == DocKind.invoice) {
        for (final p in d.payments) {
          if (p.date.year == year && p.date.month == month) sum += p.amount;
        }
      }
    }
    return sum;
  }

  double invoicedIn(int year, int month) => invoices
      .where((d) => d.date.year == year && d.date.month == month)
      .fold(0, (s, d) => s + d.total);

  // ───────── clients & items ─────────

  Future<void> upsertClient(Client c) async {
    final i = clients.indexWhere((x) => x.id == c.id);
    i < 0 ? clients.add(c) : clients[i] = c;
    await save();
  }

  Future<void> deleteClient(Client c) async {
    clients.removeWhere((x) => x.id == c.id);
    await save();
  }

  double clientBalance(Client c) =>
      invoices.where((d) => d.client.id == c.id).fold(0, (s, d) => s + d.balance);

  Future<void> upsertItem(Item it) async {
    final i = items.indexWhere((x) => x.id == it.id);
    i < 0 ? items.add(it) : items[i] = it;
    await save();
  }

  Future<void> deleteItem(Item it) async {
    items.removeWhere((x) => x.id == it.id);
    await save();
  }

  /// Remember new line items in the catalog automatically.
  Future<void> learnItems(List<Line> lines) async {
    var changed = false;
    for (final l in lines) {
      final name = l.name.trim();
      if (name.isEmpty) continue;
      final i = items.indexWhere((x) => x.name.toLowerCase() == name.toLowerCase());
      if (i < 0) {
        items.add(Item(id: newId(), name: name, unit: l.unit, price: l.price, taxRate: l.taxRate));
        changed = true;
      } else if (items[i].price != l.price && l.price > 0) {
        items[i].price = l.price;
        changed = true;
      }
    }
    if (changed) await save();
  }

  // ───────── letters ─────────

  Future<void> saveLetter(Letter l) async {
    final i = letters.indexWhere((x) => x.id == l.id);
    i < 0 ? letters.add(l) : letters[i] = l;
    await save();
  }

  Future<void> deleteLetter(Letter l) async {
    letters.removeWhere((x) => x.id == l.id);
    await save();
  }

  // ───────── files ─────────

  Future<String> saveMedia(List<int> bytes, String ext) async {
    final f = File('${root.path}/media/${newId()}.$ext');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  Future<File> export(String name, List<int> bytes) async {
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final f = File('${root.path}/exports/$safe');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }
}
