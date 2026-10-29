import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';

/// Builds every PDF the app shares: invoices & co, receipts, letters, CVs.
class PdfService {
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> theme() async {
    if (_theme != null) return _theme!;
    Future<pw.Font> f(String n) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$n.ttf'));
    final bnR = await f('NotoSansBengali-Regular'), bnB = await f('NotoSansBengali-Bold');
    return _theme = pw.ThemeData.withFont(
      base: await f('NotoSans-Regular'),
      bold: await f('NotoSans-Bold'),
      fontFallback: [bnR, bnB],
    );
  }

  static String money(double v, String cur) =>
      '$cur${NumberFormat('#,##0.00').format(v)}';

  static final _date = DateFormat('d MMM yyyy');

  static pw.ImageProvider? _img(String? path) {
    if (path == null) return null;
    final f = File(path);
    return f.existsSync() ? pw.MemoryImage(f.readAsBytesSync()) : null;
  }

  static const templates = ['Modern', 'Classic', 'Minimal'];

  // ───────────────────────── Invoice family ─────────────────────────

  static Future<Uint8List> document(Business b, BizDoc d, {bool watermark = false}) async {
    final t = await theme();
    if (d.kind == DocKind.receipt && d.lines.isEmpty) {
      return _receipt(b, d, t, watermark);
    }
    final brand = PdfColor.fromInt(b.brandColor);
    // PDF fills ignore alpha, so tint by mixing the brand colour with white.
    final light = PdfColor(1 - (1 - brand.red) * 0.12, 1 - (1 - brand.green) * 0.12, 1 - (1 - brand.blue) * 0.12);
    final logo = _img(b.logoPath);
    final doc = pw.Document(theme: t);
    final tpl = b.template;
    final title = d.title.isNotEmpty ? d.title : d.kind.label.toUpperCase();

    pw.Widget header() {
      final info = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(b.name.isEmpty ? 'Your Business' : b.name,
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: tpl == 0 ? PdfColors.white : brand)),
          if (b.tagline.isNotEmpty)
            pw.Text(b.tagline,
                style: pw.TextStyle(fontSize: 9, color: tpl == 0 ? PdfColors.white : PdfColors.grey700)),
          pw.SizedBox(height: 4),
          for (final line in [b.address, b.phone, b.email, b.website, if (b.taxId.isNotEmpty) 'Tax/BIN: ${b.taxId}'])
            if (line.trim().isNotEmpty)
              pw.Text(line,
                  style: pw.TextStyle(fontSize: 8.5, color: tpl == 0 ? PdfColors.white : PdfColors.grey800)),
        ],
      );
      final meta = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: tpl == 0 ? PdfColors.white : brand,
                  letterSpacing: 1.5)),
          pw.SizedBox(height: 6),
          _kv('No.', d.number, tpl == 0),
          _kv('Date', _date.format(d.date), tpl == 0),
          if (d.dueDate != null && d.kind.hasDueDate) _kv('Due', _date.format(d.dueDate!), tpl == 0),
        ],
      );
      final row = pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null) ...[
            pw.Container(
              width: 56,
              height: 56,
              decoration: tpl == 0
                  ? pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(8))
                  : null,
              padding: const pw.EdgeInsets.all(4),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(child: info),
          meta,
        ],
      );
      if (tpl == 0) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(color: brand, borderRadius: pw.BorderRadius.circular(10)),
          child: row,
        );
      }
      return pw.Column(children: [
        row,
        pw.SizedBox(height: 10),
        pw.Container(height: tpl == 1 ? 2.5 : 0.8, color: tpl == 1 ? brand : PdfColors.grey400),
      ]);
    }

    pw.Widget party() {
      final c = d.client;
      return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: tpl == 2 ? null : light,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(d.kind.partyLabel.toUpperCase(),
                  style: pw.TextStyle(fontSize: 8, color: brand, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              pw.SizedBox(height: 3),
              pw.Text(c.name.isEmpty ? '—' : c.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              for (final l in [c.company, c.address, c.phone, c.email])
                if (l.trim().isNotEmpty) pw.Text(l, style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
        ),
        pw.SizedBox(width: 12),
        if (d.kind == DocKind.invoice)
          pw.Container(
            width: 150,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: brand, width: 1),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('BALANCE DUE', style: pw.TextStyle(fontSize: 8, color: brand, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text(money(d.balance, b.currency),
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
      ]);
    }

    pw.Widget table() {
      final prices = d.kind.hasPrices;
      final hasTax = d.lines.any((l) => l.taxRate > 0);
      final headers = [
        '#',
        'Item / Description',
        'Qty',
        if (prices) 'Rate',
        if (prices && hasTax) 'Tax',
        if (prices) 'Amount',
      ];
      final rows = <List<String>>[
        for (var i = 0; i < d.lines.length; i++)
          [
            '${i + 1}',
            d.lines[i].description.isEmpty
                ? d.lines[i].name
                : '${d.lines[i].name}\n${d.lines[i].description}',
            '${_num(d.lines[i].qty)} ${d.lines[i].unit}',
            if (prices) money(d.lines[i].price, b.currency),
            if (prices && hasTax) '${_num(d.lines[i].taxRate)}%',
            if (prices) money(d.lines[i].amount, b.currency),
          ]
      ];
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        border: tpl == 1 ? pw.TableBorder.all(color: PdfColors.grey400, width: 0.5) : null,
        headerStyle: pw.TextStyle(color: tpl == 2 ? brand : PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
        headerDecoration: tpl == 2
            ? const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600)))
            : pw.BoxDecoration(color: brand),
        cellStyle: const pw.TextStyle(fontSize: 9),
        rowDecoration: tpl == 1
            ? null
            : const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        oddRowDecoration: tpl == 0 ? pw.BoxDecoration(color: light) : null,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        columnWidths: {
          0: const pw.FixedColumnWidth(22),
          1: const pw.FlexColumnWidth(4),
          2: const pw.FlexColumnWidth(1.4),
        },
        cellAlignments: {
          0: pw.Alignment.center,
          for (var i = 2; i < headers.length; i++) i: pw.Alignment.centerRight,
        },
      );
    }

    pw.Widget totals() {
      if (!d.kind.hasPrices) return pw.SizedBox();
      final rows = <(String, String, bool)>[
        ('Subtotal', money(d.subtotal, b.currency), false),
        if (d.discountValue > 0)
          ('Discount${d.discountIsPercent ? ' (${_num(d.discount)}%)' : ''}', '- ${money(d.discountValue, b.currency)}', false),
        if (d.taxTotal > 0) ('Tax / VAT', money(d.taxTotal, b.currency), false),
        if (d.shipping > 0) ('Shipping', money(d.shipping, b.currency), false),
        ('Total', money(d.total, b.currency), true),
        if (d.kind == DocKind.invoice && d.paid > 0) ('Paid', '- ${money(d.paid, b.currency)}', false),
        if (d.kind == DocKind.invoice && d.paid > 0) ('Balance Due', money(d.balance, b.currency), true),
      ];
      return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 16, top: 4),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Amount in words', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text(amountInWords(d.total, b.currency),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
        ),
        pw.SizedBox(
          width: 220,
          child: pw.Column(children: [
            for (final r in rows)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: r.$3
                    ? pw.BoxDecoration(color: tpl == 2 ? light : brand, borderRadius: pw.BorderRadius.circular(4))
                    : null,
                child: pw.Row(children: [
                  pw.Expanded(
                    child: pw.Text(r.$1,
                        style: pw.TextStyle(
                            fontSize: r.$3 ? 11 : 9.5,
                            fontWeight: r.$3 ? pw.FontWeight.bold : null,
                            color: r.$3 && tpl != 2 ? PdfColors.white : null)),
                  ),
                  pw.Text(r.$2,
                      style: pw.TextStyle(
                          fontSize: r.$3 ? 11 : 9.5,
                          fontWeight: r.$3 ? pw.FontWeight.bold : null,
                          color: r.$3 && tpl != 2 ? PdfColors.white : null)),
                ]),
              ),
          ]),
        ),
      ]);
    }

    pw.Widget footer() {
      final sig = _img(b.signaturePath), seal = _img(b.sealPath);
      final pay = b.paymentInfo.trim();
      return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (d.notes.trim().isNotEmpty) ...[
              _label('Notes', brand),
              pw.Text(d.notes, style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 8),
            ],
            if (d.terms.trim().isNotEmpty) ...[
              _label('Terms & Conditions', brand),
              pw.Text(d.terms, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
              pw.SizedBox(height: 8),
            ],
            if (pay.isNotEmpty && d.kind == DocKind.invoice)
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: pay, width: 58, height: 58),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    _label('Payment details', brand),
                    pw.Text(pay, style: const pw.TextStyle(fontSize: 8.5)),
                  ]),
                ),
              ]),
          ]),
        ),
        pw.SizedBox(width: 16),
        pw.SizedBox(
          width: 150,
          child: pw.Column(children: [
            pw.SizedBox(
              height: 60,
              child: pw.Stack(alignment: pw.Alignment.center, children: [
                if (seal != null) pw.Opacity(opacity: 0.85, child: pw.Image(seal, height: 58)),
                if (sig != null) pw.Image(sig, height: 44),
              ]),
            ),
            pw.Container(height: 0.8, color: PdfColors.grey600),
            pw.SizedBox(height: 3),
            pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          ]),
        ),
      ]);
    }

    final paid = d.kind == DocKind.invoice && d.liveStatus == DocStatus.paid;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 28),
      footer: (ctx) => pw.Row(children: [
        if (watermark)
          pw.Text('Made with QuickOffice', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
        pw.Spacer(),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
      ]),
      build: (_) => [
        header(),
        pw.SizedBox(height: 16),
        party(),
        pw.SizedBox(height: 16),
        table(),
        pw.SizedBox(height: 12),
        totals(),
        pw.SizedBox(height: 22),
        footer(),
        if (paid)
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Transform.rotate(
              angle: 0.25,
              child: pw.Container(
                margin: const pw.EdgeInsets.only(top: 10),
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.green700, width: 2.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text('PAID',
                    style: pw.TextStyle(fontSize: 26, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
              ),
            ),
          ),
      ],
    ));
    return doc.save();
  }

  static Future<Uint8List> _receipt(Business b, BizDoc d, pw.ThemeData t, bool watermark) async {
    final brand = PdfColor.fromInt(b.brandColor);
    final logo = _img(b.logoPath), sig = _img(b.signaturePath), seal = _img(b.sealPath);
    final doc = pw.Document(theme: t);
    pw.Widget field(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 7),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.SizedBox(width: 150, child: pw.Text(label, style: const pw.TextStyle(fontSize: 11))),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 2),
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.6, style: pw.BorderStyle.dashed))),
                child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ),
            ),
          ]),
        );
    // Half A4 landscape, the usual money-receipt book size.
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(PdfPageFormat.a4.height, PdfPageFormat.a4.width / 2 + 60, marginAll: 28),
      build: (_) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: brand, width: 2),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        padding: const pw.EdgeInsets.all(18),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(children: [
            if (logo != null) ...[pw.Image(logo, width: 46, height: 46), pw.SizedBox(width: 10)],
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(b.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: brand)),
                pw.Text([b.address, b.phone].where((e) => e.isNotEmpty).join(' · '),
                    style: const pw.TextStyle(fontSize: 8.5)),
              ]),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(color: brand, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text('MONEY RECEIPT',
                  style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ),
          ]),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            pw.Text('No: ${d.number}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Spacer(),
            pw.Text('Date: ${_date.format(d.date)}'),
          ]),
          pw.SizedBox(height: 6),
          field('Received with thanks from', d.client.name),
          field('The sum of', amountInWords(d.total, b.currency)),
          field('For', d.receivedFor.isEmpty ? d.notes : d.receivedFor),
          field('Payment by', d.paymentMethod),
          pw.Spacer(),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: brand, width: 1.5), borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(money(d.total, b.currency), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Spacer(),
            pw.SizedBox(
              width: 160,
              child: pw.Column(children: [
                pw.SizedBox(
                  height: 50,
                  child: pw.Stack(alignment: pw.Alignment.center, children: [
                    if (seal != null) pw.Opacity(opacity: 0.85, child: pw.Image(seal, height: 50)),
                    if (sig != null) pw.Image(sig, height: 38),
                  ]),
                ),
                pw.Container(height: 0.8, color: PdfColors.grey600),
                pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 8.5)),
              ]),
            ),
          ]),
          if (watermark)
            pw.Text('Made with QuickOffice', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
        ]),
      ),
    ));
    return doc.save();
  }

  // ───────────────────────── Letters ─────────────────────────

  static Future<Uint8List> letter(Business b, Letter l, {bool watermark = false}) async {
    final t = await theme();
    final brand = PdfColor.fromInt(b.brandColor);
    final logo = _img(b.logoPath), sig = _img(b.signaturePath), seal = _img(b.sealPath);
    final doc = pw.Document(theme: t);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 36, 44, 36),
      header: (_) => pw.Column(children: [
        pw.Row(children: [
          if (logo != null) ...[pw.Image(logo, width: 52, height: 52), pw.SizedBox(width: 12)],
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(b.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: brand)),
              if (b.tagline.isNotEmpty) pw.Text(b.tagline, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            for (final x in [b.address, b.phone, b.email, b.website])
              if (x.isNotEmpty) pw.Text(x, style: const pw.TextStyle(fontSize: 8.5)),
          ]),
        ]),
        pw.SizedBox(height: 8),
        pw.Container(height: 2, color: brand),
        pw.SizedBox(height: 18),
      ]),
      footer: (ctx) => pw.Column(children: [
        pw.Container(height: 0.6, color: brand),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          if (watermark) pw.Text('Made with QuickOffice', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          pw.Spacer(),
          pw.Text(b.name, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
        ]),
      ]),
      build: (_) => [
        pw.Row(children: [
          pw.Text('Ref: ${b.name.isEmpty ? 'REF' : b.name.split(' ').first.toUpperCase()}/${l.date.year}/${l.id.substring(0, 4).toUpperCase()}',
              style: const pw.TextStyle(fontSize: 10)),
          pw.Spacer(),
          pw.Text('Date: ${_date.format(l.date)}', style: const pw.TextStyle(fontSize: 10)),
        ]),
        pw.SizedBox(height: 16),
        if (l.to.trim().isNotEmpty) ...[
          pw.Text('To,', style: const pw.TextStyle(fontSize: 10.5)),
          pw.Text(l.to, style: const pw.TextStyle(fontSize: 10.5)),
          pw.SizedBox(height: 14),
        ],
        if (l.subject.trim().isNotEmpty) ...[
          pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Subject: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.TextSpan(text: l.subject, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, decoration: pw.TextDecoration.underline)),
            ]),
          ),
          pw.SizedBox(height: 14),
        ],
        for (final p in l.body.split(RegExp(r'\n\s*\n')))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 9),
            child: pw.Text(p.trim(), textAlign: pw.TextAlign.justify, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2.5)),
          ),
        pw.SizedBox(height: 24),
        pw.Text('Sincerely,', style: const pw.TextStyle(fontSize: 10.5)),
        pw.SizedBox(
          height: 64,
          width: 170,
          child: pw.Stack(alignment: pw.Alignment.centerLeft, children: [
            if (seal != null) pw.Positioned(left: 60, child: pw.Opacity(opacity: 0.85, child: pw.Image(seal, height: 62))),
            if (sig != null) pw.Image(sig, height: 46),
          ]),
        ),
        pw.Container(width: 170, height: 0.7, color: PdfColors.grey600),
        pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(b.name, style: const pw.TextStyle(fontSize: 9.5)),
      ],
    ));
    return doc.save();
  }

  // ───────────────────────── CV ─────────────────────────

  static Future<Uint8List> cv(Map<String, String> cv, String? photoPath, int color, {bool watermark = false}) async {
    final t = await theme();
    final brand = PdfColor.fromInt(color);
    final photo = _img(photoPath);
    String v(String k) => (cv[k] ?? '').trim();
    final doc = pw.Document(theme: t);
    pw.Widget section(String title, String body, {bool light = false}) => body.isEmpty
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 14),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(title.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 10.5, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2, color: light ? PdfColors.white : brand)),
              pw.Container(height: 1.2, width: 34, color: light ? PdfColors.white : brand, margin: const pw.EdgeInsets.symmetric(vertical: 4)),
              for (final line in body.split('\n'))
                if (line.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2.5),
                    child: pw.Text(line.trim(),
                        style: pw.TextStyle(fontSize: 9.5, color: light ? PdfColors.white : PdfColors.grey900, lineSpacing: 1.5)),
                  ),
            ]),
          );
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Container(
          width: 190,
          color: brand,
          padding: const pw.EdgeInsets.fromLTRB(20, 32, 18, 24),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (photo != null)
              pw.Center(
                child: pw.Container(
                  width: 110,
                  height: 110,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: PdfColors.white, width: 3),
                    image: pw.DecorationImage(image: photo, fit: pw.BoxFit.cover),
                  ),
                ),
              ),
            pw.SizedBox(height: 18),
            section('Contact', [v('phone'), v('email'), v('address'), v('linkedin')].where((e) => e.isNotEmpty).join('\n'), light: true),
            section('Skills', v('skills').replaceAll(',', '\n'), light: true),
            section('Languages', v('languages').replaceAll(',', '\n'), light: true),
          ]),
        ),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(26, 34, 30, 24),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(v('name'), style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: brand)),
              pw.Text(v('title'), style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
              pw.SizedBox(height: 18),
              section('Profile', v('summary')),
              section('Experience', v('experience')),
              section('Education', v('education')),
              section('Training & Certificates', v('certificates')),
              section('References', v('references')),
              pw.Spacer(),
              if (watermark) pw.Text('Made with QuickOffice', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            ]),
          ),
        ),
      ]),
    ));
    return doc.save();
  }

  // ───────────────────────── helpers ─────────────────────────

  static pw.Widget _kv(String k, String v, bool onBrand) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1.5),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(text: '$k: ', style: pw.TextStyle(fontSize: 9, color: onBrand ? PdfColors.white : PdfColors.grey700)),
            pw.TextSpan(
                text: v,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: onBrand ? PdfColors.white : PdfColors.black)),
          ]),
        ),
      );

  static pw.Widget _label(String s, PdfColor c) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Text(s, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: c)),
      );

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static const _currencyWords = {
    '৳': ('Taka', 'Paisa'),
    '\$': ('Dollars', 'Cents'),
    '₹': ('Rupees', 'Paise'),
    '€': ('Euros', 'Cents'),
    '£': ('Pounds', 'Pence'),
    'Rs': ('Rupees', 'Paisa'),
    'SAR': ('Riyals', 'Halalas'),
    'AED': ('Dirhams', 'Fils'),
    'RM': ('Ringgit', 'Sen'),
  };

  /// "Taka Five Thousand Two Hundred Only".
  static String amountInWords(double amount, String currency) {
    final names = _currencyWords[currency.trim()] ?? ('', 'Cents');
    final whole = amount.floor();
    final cents = ((amount - whole) * 100).round();
    var s = '${names.$1} ${_words(whole)}'.trim();
    if (cents > 0) s += ' and ${_words(cents)} ${names.$2}';
    return '$s Only';
  }

  static const _ones = [
    'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
    'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
  ];
  static const _tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  static String _words(int n) {
    if (n < 20) return _ones[n];
    if (n < 100) return '${_tens[n ~/ 10]}${n % 10 > 0 ? ' ${_ones[n % 10]}' : ''}';
    if (n < 1000) return '${_ones[n ~/ 100]} Hundred${n % 100 > 0 ? ' ${_words(n % 100)}' : ''}';
    for (final (div, name) in [(1000000000, 'Billion'), (1000000, 'Million'), (1000, 'Thousand')]) {
      if (n >= div) return '${_words(n ~/ div)} $name${n % div > 0 ? ' ${_words(n % div)}' : ''}';
    }
    return '$n';
  }
}
