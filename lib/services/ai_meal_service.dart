import 'dart:convert';
import 'dart:typed_data';
import '../config/secrets.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String _geminiApiKey = geminiApiKey;
const String _model = 'gemini-2.0-flash';

const String _systemPrompt =
    'You are a precise macro calculator. Analyze this food image. '
    'Return ONLY a raw, unformatted JSON object. '
    'Do not include any markdown, code blocks, or extra text. '
    'The JSON keys must be exactly: "kcal", "carbs", "protein", "fat". '
    'All values must be integers.';

Future<Map<String, int>?> analyzeMeal(Uint8List imageBytes) async {
  if (_geminiApiKey.isEmpty) {
    debugPrint('analyzeMeal: GEMINI_API_KEY is not set.');
    return null;
  }

  final String url =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_geminiApiKey';
  final Uri uri = Uri.parse(url);

  final String base64Image = base64Encode(imageBytes);

  final Map<String, dynamic> requestBody = {
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': _systemPrompt},
          {
            'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
          },
        ],
      },
    ],
  };

  try {
    debugPrint('--- [AI SCAN] SENDING REQUEST ---');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    debugPrint('--- [AI SCAN] STATUS CODE: ${response.statusCode} ---');
    debugPrint('--- [AI SCAN] RAW RESPONSE: ${response.body} ---');

    if (response.statusCode != 200) {
      debugPrint('--- [AI SCAN] ERROR: API rejected request ---');
      return null;
    }

    final Map<String, dynamic> decoded = jsonDecode(response.body);
    final String? text =
        decoded['candidates']?[0]['content']?['parts']?[0]['text'];

    if (text == null || text.isEmpty) {
      debugPrint('--- [AI SCAN] ERROR: No text in response ---');
      return null;
    }

    final String cleaned = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    debugPrint('--- [AI SCAN] PARSED TEXT: $cleaned ---');

    final Map<String, dynamic> parsed = jsonDecode(cleaned);

    return {
      'kcal': (parsed['kcal'] as num).toInt(),
      'carbs': (parsed['carbs'] as num).toInt(),
      'protein': (parsed['protein'] as num).toInt(),
      'fat': (parsed['fat'] as num).toInt(),
    };
  } catch (e) {
    debugPrint('--- [AI SCAN] EXCEPTION: $e ---');
    return null;
  }
}
