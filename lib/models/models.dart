import 'package:flutter/material.dart';

/// Kinds of business documents the app makes.
enum DocKind {
  invoice('Invoice', 'INV', Icons.receipt_long_rounded),
  estimate('Quotation', 'QT', Icons.request_quote_rounded),
  receipt('Money Receipt', 'MR', Icons.payments_rounded),
  purchaseOrder('Purchase Order', 'PO', Icons.shopping_cart_checkout_rounded),
  challan('Delivery Challan', 'DC', Icons.local_shipping_rounded);

  const DocKind(this.label, this.prefix, this.icon);
  final String label, prefix;
  final IconData icon;

  /// Who the document is addressed to.
  String get partyLabel => this == DocKind.purchaseOrder ? 'Supplier' : 'Bill to';
  bool get hasPrices => this != DocKind.challan;
  bool get hasDueDate => this == DocKind.invoice;
}

enum DocStatus { draft, sent, paid, partial, overdue, cancelled }

class Business {
  Business({
    this.name = '',
    this.tagline = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.taxId = '',
    this.currency = '৳',
    this.logoPath,
    this.signaturePath,
    this.sealPath,
    this.paymentInfo = '',
    this.terms = 'Thank you for your business!',
    this.taxRate = 0,
    this.brandColor = 0xFF0E9F6E,
    this.template = 0,
  });

  String name, tagline, address, phone, email, website, taxId, currency;
  String? logoPath, signaturePath, sealPath;

  /// Bank / bKash / UPI details printed on invoices (+ QR).
  String paymentInfo;
  String terms;
  double taxRate;
  int brandColor;
  int template;

  bool get isSet => name.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'name': name,
        'tagline': tagline,
        'address': address,
        'phone': phone,
        'email': email,
        'website': website,
        'taxId': taxId,
        'currency': currency,
        'logoPath': logoPath,
        'signaturePath': signaturePath,
        'sealPath': sealPath,
        'paymentInfo': paymentInfo,
        'terms': terms,
        'taxRate': taxRate,
        'brandColor': brandColor,
        'template': template,
      };

  factory Business.fromJson(Map<String, dynamic> j) => Business(
        name: j['name'] ?? '',
        tagline: j['tagline'] ?? '',
        address: j['address'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'] ?? '',
        website: j['website'] ?? '',
        taxId: j['taxId'] ?? '',
        currency: j['currency'] ?? '৳',
        logoPath: j['logoPath'],
        signaturePath: j['signaturePath'],
        sealPath: j['sealPath'],
        paymentInfo: j['paymentInfo'] ?? '',
        terms: j['terms'] ?? '',
        taxRate: (j['taxRate'] ?? 0).toDouble(),
        brandColor: j['brandColor'] ?? 0xFF0E9F6E,
        template: j['template'] ?? 0,
      );
}

class Client {
  Client({
    required this.id,
    this.name = '',
    this.company = '',
    this.phone = '',
    this.email = '',
    this.address = '',
  });
  final String id;
  String name, company, phone, email, address;

  String get display => company.isNotEmpty ? '$name · $company' : name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'company': company,
        'phone': phone,
        'email': email,
        'address': address,
      };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: j['id'],
        name: j['name'] ?? '',
        company: j['company'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'] ?? '',
        address: j['address'] ?? '',
      );

  Client copy() => Client.fromJson(toJson());
}

/// Catalog item (product / service) for quick re-use.
class Item {
  Item({required this.id, this.name = '', this.unit = 'pcs', this.price = 0, this.taxRate = 0});
  final String id;
  String name, unit;
  double price, taxRate;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'unit': unit, 'price': price, 'taxRate': taxRate};

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'],
        name: j['name'] ?? '',
        unit: j['unit'] ?? 'pcs',
        price: (j['price'] ?? 0).toDouble(),
        taxRate: (j['taxRate'] ?? 0).toDouble(),
      );
}

class Line {
  Line({this.name = '', this.description = '', this.qty = 1, this.unit = 'pcs', this.price = 0, this.taxRate = 0});
  String name, description, unit;
  double qty, price, taxRate;

  double get amount => qty * price;
  double get tax => amount * taxRate / 100;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'qty': qty,
        'unit': unit,
        'price': price,
        'taxRate': taxRate,
      };

  factory Line.fromJson(Map<String, dynamic> j) => Line(
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        qty: (j['qty'] ?? 1).toDouble(),
        unit: j['unit'] ?? 'pcs',
        price: (j['price'] ?? 0).toDouble(),
        taxRate: (j['taxRate'] ?? 0).toDouble(),
      );
}

class Payment {
  Payment({required this.date, required this.amount, this.method = 'Cash', this.note = ''});
  final DateTime date;
  final double amount;
  final String method, note;

  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'amount': amount, 'method': method, 'note': note};

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        date: DateTime.parse(j['date']),
        amount: (j['amount'] ?? 0).toDouble(),
        method: j['method'] ?? 'Cash',
        note: j['note'] ?? '',
      );
}

class BizDoc {
  BizDoc({
    required this.id,
    required this.kind,
    required this.number,
    required this.date,
    this.dueDate,
    Client? client,
    List<Line>? lines,
    List<Payment>? payments,
    this.discount = 0,
    this.discountIsPercent = false,
    this.shipping = 0,
    this.notes = '',
    this.terms = '',
    this.status = DocStatus.draft,
    this.title = '',
    this.amountReceived,
    this.receivedFor = '',
    this.paymentMethod = 'Cash',
  })  : client = client ?? Client(id: ''),
        lines = lines ?? [],
        payments = payments ?? [];

  final String id;
  final DocKind kind;
  String number;
  DateTime date;
  DateTime? dueDate;
  Client client;
  List<Line> lines;
  List<Payment> payments;
  double discount;
  bool discountIsPercent;
  double shipping;
  String notes, terms, title;
  DocStatus status;

  /// Money receipt fields.
  double? amountReceived;
  String receivedFor, paymentMethod;

  double get subtotal => lines.fold(0, (s, l) => s + l.amount);
  double get taxTotal => lines.fold(0, (s, l) => s + l.tax);
  double get discountValue => discountIsPercent ? subtotal * discount / 100 : discount;
  double get total {
    if (kind == DocKind.receipt && lines.isEmpty) return amountReceived ?? 0;
    return (subtotal - discountValue + taxTotal + shipping).clamp(0, double.infinity);
  }

  double get paid => kind == DocKind.receipt
      ? total
      : payments.fold(0, (s, p) => s + p.amount);
  double get balance => (total - paid).clamp(0, double.infinity);

  /// Status computed from payments and due date (manual draft/cancel kept).
  DocStatus get liveStatus {
    if (status == DocStatus.cancelled || status == DocStatus.draft) return status;
    if (kind != DocKind.invoice) return status;
    if (total > 0 && balance <= 0.009) return DocStatus.paid;
    if (dueDate != null && DateTime.now().isAfter(dueDate!.add(const Duration(days: 1)))) {
      return DocStatus.overdue;
    }
    if (paid > 0) return DocStatus.partial;
    return DocStatus.sent;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'number': number,
        'date': date.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'client': client.toJson(),
        'lines': [for (final l in lines) l.toJson()],
        'payments': [for (final p in payments) p.toJson()],
        'discount': discount,
        'discountIsPercent': discountIsPercent,
        'shipping': shipping,
        'notes': notes,
        'terms': terms,
        'status': status.name,
        'title': title,
        'amountReceived': amountReceived,
        'receivedFor': receivedFor,
        'paymentMethod': paymentMethod,
      };

  factory BizDoc.fromJson(Map<String, dynamic> j) => BizDoc(
        id: j['id'],
        kind: DocKind.values.byName(j['kind']),
        number: j['number'] ?? '',
        date: DateTime.parse(j['date']),
        dueDate: j['dueDate'] == null ? null : DateTime.parse(j['dueDate']),
        client: Client.fromJson(Map<String, dynamic>.from(j['client'] ?? {'id': ''})),
        lines: [for (final l in (j['lines'] as List? ?? [])) Line.fromJson(Map<String, dynamic>.from(l))],
        payments: [
          for (final p in (j['payments'] as List? ?? [])) Payment.fromJson(Map<String, dynamic>.from(p))
        ],
        discount: (j['discount'] ?? 0).toDouble(),
        discountIsPercent: j['discountIsPercent'] ?? false,
        shipping: (j['shipping'] ?? 0).toDouble(),
        notes: j['notes'] ?? '',
        terms: j['terms'] ?? '',
        status: DocStatus.values.byName(j['status'] ?? 'draft'),
        title: j['title'] ?? '',
        amountReceived: (j['amountReceived'] as num?)?.toDouble(),
        receivedFor: j['receivedFor'] ?? '',
        paymentMethod: j['paymentMethod'] ?? 'Cash',
      );

  BizDoc copyAs(DocKind k, String id, String number) {
    final j = toJson()
      ..['id'] = id
      ..['kind'] = k.name
      ..['number'] = number
      ..['status'] = DocStatus.draft.name
      ..['payments'] = []
      ..['date'] = DateTime.now().toIso8601String();
    return BizDoc.fromJson(j);
  }
}

/// A saved official letter.
class Letter {
  Letter({required this.id, required this.type, required this.date, this.to = '', this.subject = '', this.body = ''});
  final String id;
  String type, to, subject, body;
  DateTime date;

  Map<String, dynamic> toJson() =>
      {'id': id, 'type': type, 'date': date.toIso8601String(), 'to': to, 'subject': subject, 'body': body};

  factory Letter.fromJson(Map<String, dynamic> j) => Letter(
        id: j['id'],
        type: j['type'] ?? '',
        date: DateTime.parse(j['date']),
        to: j['to'] ?? '',
        subject: j['subject'] ?? '',
        body: j['body'] ?? '',
      );
}
