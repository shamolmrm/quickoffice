import 'package:flutter_test/flutter_test.dart';
import 'package:quickoffice/models/models.dart';
import 'package:quickoffice/services/pdf_service.dart';

void main() {
  test('amount in words', () {
    expect(PdfService.amountInWords(5250, '৳'), 'Taka Five Thousand Two Hundred Fifty Only');
    expect(PdfService.amountInWords(1001.5, '\$'), 'Dollars One Thousand One and Fifty Cents Only');
    expect(PdfService.amountInWords(0, '৳'), 'Taka Zero Only');
  });

  test('invoice totals, discount, tax and balance', () {
    final d = BizDoc(
      id: 'x',
      kind: DocKind.invoice,
      number: 'INV-0001',
      date: DateTime(2026, 1, 1),
      dueDate: DateTime(2099, 1, 1),
      status: DocStatus.sent,
      lines: [
        Line(name: 'Cement', qty: 10, price: 550),
        Line(name: 'Rod', qty: 2, price: 1000, taxRate: 5),
      ],
      discount: 10,
      discountIsPercent: true,
      shipping: 300,
    );
    expect(d.subtotal, 7500);
    expect(d.discountValue, 750);
    expect(d.taxTotal, 100);
    expect(d.total, 7150);
    d.payments.add(Payment(date: DateTime.now(), amount: 7150));
    expect(d.balance, 0);
    expect(d.liveStatus, DocStatus.paid);
  });
}
