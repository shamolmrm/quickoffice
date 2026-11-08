# QuickOffice — pocket office for small businesses

Flutter app for shops, freelancers, small companies, offices and NGOs: make **invoices, quotations, money receipts, letters, seals and CVs** from the phone, and keep track of who paid and what is still due.

## Features
- One-time business setup: name, logo, signature (drawn by finger), seal, address, tax/BIN/VAT, currency (৳, $, ₹, €, £, SAR, AED …), payment details (bKash, bank) with QR code on invoices
- Documents: invoice, quotation, money receipt, delivery challan, purchase order, report
- Letters: appointment, experience, salary certificate, NOC and more
- Seal maker and letterhead
- CV / resume builder
- Clients and payment tracking (paid / due), reports
- PDF export, print and share
- Payment reminders (local notifications)
- AI writing help
- Free with ads; Premium via in-app purchase

## Stack
Flutter · Provider · `pdf` + `printing` · shared_preferences · signature · image_picker / file_picker · Google Mobile Ads · in_app_purchase · flutter_local_notifications

## Code layout
```
lib/screens/   business, clients, docs, doc editor/viewer, letters, CV, seal, reports, premium
lib/services/  pdf_service, store, premium_service, ad_gate, ai_service, reminder_service, seal_painter
lib/models/    data models
```

## Build
Secrets (`keys.json`, signing key) are gitignored.
```powershell
flutter pub get
flutter run
.\build_release.ps1     # release bundle
```

User guide (Banglish): [`QuickOffice_Guide.md`](QuickOffice_Guide.md)
