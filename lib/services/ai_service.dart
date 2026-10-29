import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ad_gate.dart';
import 'env.dart';
import 'settings.dart';

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Google Gemini for invoice parsing, letters, reminders and CV help.
class AiService {
  AiService(this.settings);
  final AppSettings settings;

  Future<String> _key() async {
    if (settings.hasOwnKey) return settings.apiKey;
    if (!Env.hasBuiltInKey) throw AiException('Add a Gemini API key in Settings → AI.');
    if (AdGate.aiUnlocked || await AdGate.unlockAi()) return Env.geminiKey;
    throw AiException('AI needs Premium or a short ad.');
  }

  Future<String> _generate(String prompt, {bool json = false, double temperature = 0.4}) async {
    final key = await _key();
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        if (json) 'responseMimeType': 'application/json',
      },
    });
    Future<http.Response> call(String model) => http
        .post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
          body: body,
        )
        .timeout(const Duration(seconds: 90));
    http.Response res;
    try {
      res = await call(settings.model);
      if (res.statusCode == 404 && settings.model != AppSettings.defaultModel) {
        res = await call(AppSettings.defaultModel);
      }
    } on SocketException {
      throw AiException('No internet connection.');
    }
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      final err = data is Map ? data['error'] : null;
      throw AiException((err is Map ? err['message'] : null)?.toString() ?? 'AI error ${res.statusCode}');
    }
    final parts = data['candidates']?[0]?['content']?['parts'] as List?;
    final text = parts?.map((p) => p['text'] ?? '').join().trim() ?? '';
    if (text.isEmpty) throw AiException('AI returned nothing.');
    return text;
  }

  /// "10 bags cement 550 each for Rahim Traders" → client + lines.
  Future<Map<String, dynamic>> parseInvoice(String text, String currency) async {
    final raw = await _generate(
      'Turn this request (may be Bangla or English) into invoice data. Return JSON: '
      '{"client": {"name": "", "company": "", "phone": "", "address": ""}, '
      '"items": [{"name": "", "qty": 1, "unit": "pcs", "price": 0}], '
      '"discount": 0, "notes": ""}. Prices are in $currency. Use English item '
      'names unless the user wrote Bangla. Empty strings for unknown fields.\n\n$text',
      json: true,
      temperature: 0,
    );
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  /// Official letter. Returns subject + body (no letterhead / signature).
  Future<({String subject, String body})> letter({
    required String type,
    required String details,
    required String company,
    required String language,
  }) async {
    final raw = await _generate(
      'Write a formal "$type" on behalf of the company "$company" in $language. '
      'Details from the user: $details\n'
      'Return JSON {"subject": "...", "body": "..."}. The body starts with the '
      'salutation and ends before the signature block (no sign-off name, no '
      'letterhead, no date). Use clear paragraphs separated by blank lines. '
      'Keep it professional and concise.',
      json: true,
    );
    final j = jsonDecode(raw) as Map;
    return (subject: (j['subject'] ?? '').toString(), body: (j['body'] ?? '').toString());
  }

  Future<String> reminder({
    required String client,
    required String number,
    required String amount,
    required String due,
    required String company,
    required String language,
  }) =>
      _generate(
        'Write a short, polite WhatsApp payment reminder in $language from '
        '"$company" to "$client" for invoice $number of $amount, due $due. '
        'Max 4 lines, friendly, no placeholders.',
        temperature: 0.6,
      );

  Future<String> improve(String text, String instruction) =>
      _generate('$instruction\n\nText:\n$text\n\nReturn only the improved text.', temperature: 0.5);
}
