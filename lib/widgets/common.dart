import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/ad_gate.dart';
import '../services/premium_service.dart';
import '../services/store.dart';
import '../theme.dart';

final dateFmt = DateFormat('d MMM yyyy');

String fmtMoney(double v, String cur) => '$cur${NumberFormat('#,##0.00').format(v)}';

bool isPremium(BuildContext context) => context.read<PremiumService>().isPremium;

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset('assets/logo.png', width: size, height: size),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          ?trailing,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.cs.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final DocStatus status;

  static (String, Color) style(DocStatus s) => switch (s) {
        DocStatus.draft => ('Draft', Colors.grey),
        DocStatus.sent => ('Unpaid', AppColors.warning),
        DocStatus.paid => ('Paid', AppColors.success),
        DocStatus.partial => ('Partly paid', const Color(0xFF0EA5E9)),
        DocStatus.overdue => ('Overdue', AppColors.danger),
        DocStatus.cancelled => ('Cancelled', Colors.grey),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color) = style(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

/// Wraps a heavy async task with a blocking progress dialog.
Future<T?> withProgress<T>(BuildContext context, String label, Future<T> Function() task) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(width: 26, height: 26, child: CircularProgressIndicator()),
          const SizedBox(width: 18),
          Expanded(child: Text(label)),
        ]),
      ),
    ),
  );
  try {
    final r = await task();
    nav.pop();
    return r;
  } catch (e) {
    nav.pop();
    if (context.mounted) context.toast('$e');
    return null;
  }
}

Future<String?> promptText(BuildContext context, String title, {String initial = '', String hint = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

class FileActions {
  static Future<void> sharePdf(BuildContext context, String name, Uint8List bytes, {String? text}) async {
    final store = context.read<Store>();
    if (!await AdGate.unlock('share')) return;
    final f = await store.export(name.endsWith('.pdf') ? name : '$name.pdf', bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: text));
  }

  static Future<void> shareFile(BuildContext context, String path, {String? text}) async {
    if (!await AdGate.unlock('share')) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: text));
  }

  static Future<void> shareText(String text) => SharePlus.instance.share(ShareParams(text: text));

  static Future<void> save(BuildContext context, String name, Uint8List bytes, String mime) async {
    if (!await AdGate.unlock('download')) return;
    try {
      final uri = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mime);
      if (uri != null && context.mounted) context.toast('Saved $name');
    } catch (e) {
      if (context.mounted) context.toast('Could not save: $e');
    }
  }

  static Future<void> print(String name, Uint8List bytes) async {
    if (!await AdGate.unlock('print')) return;
    await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
  }
}

/// Full-screen PDF preview with share / save / print.
class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({super.key, required this.title, required this.bytes, this.shareText});
  final String title;
  final Uint8List bytes;
  final String? shareText;

  String get _file => '${title.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}.pdf';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: () => FileActions.print(_file, bytes)),
          IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: () => FileActions.save(context, _file, bytes, 'application/pdf')),
        ],
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        useActions: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        scrollViewDecoration: BoxDecoration(color: context.cs.surface),
      ),
      bottomNavigationBar: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AdBanner(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => FileActions.sharePdf(context, _file, bytes, text: shareText),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share PDF (WhatsApp, Email…)'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Picks an image from the gallery and stores a copy in app storage.
Future<String?> pickImageToStore(BuildContext context) async {
  final store = context.read<Store>();
  final f = await FilePicker.pickFile(type: FileType.image);
  if (f == null) return null;
  final bytes = await f.xFile.readAsBytes();
  final ext = f.name.split('.').last.toLowerCase();
  return store.saveMedia(bytes, ext.length > 4 ? 'png' : ext);
}

bool fileExists(String? p) => p != null && File(p).existsSync();
