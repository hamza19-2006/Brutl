import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Gemini API Configuration
// ---------------------------------------------------------------------------
const String _geminiApiKey = 'AIzaSyBDHjvaM7B1N-3KCLusPs_4JYZJ1m06zYs';
const String _model = 'gemini-1.5-flash';

const String _systemPrompt =
    'You are a precise macro calculator. Analyze this food image. '
    'Return ONLY a raw, unformatted JSON object. '
    'Do not include markdown code blocks (like ```json). '
    'Do not include any other words, explanations, or text. '
    'The JSON keys must be exactly: "kcal" (integer), "carbs" (integer), '
    '"protein" (integer), "fat" (integer).';

/// Sends [imageBytes] to the Gemini Vision API and returns a macro map.
Future<Map<String, int>?> analyzeMeal(Uint8List imageBytes) async {
  if (_geminiApiKey.isEmpty) {
    debugPrint('analyzeMeal: GEMINI_API_KEY is not set.');
    return null;
  }

  // Cleaned URL to remove hidden FormatException characters
  final String url =
      '[https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_geminiApiKey](https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_geminiApiKey)';
  final Uri uri = Uri.parse(url.trim());

  final String base64Image = base64Encode(imageBytes);

  final Map<String, dynamic> requestBody = {
    'system_instruction': {
      'parts': [
        {'text': _systemPrompt},
      ],
    },
    'contents': [
      {
        'role': 'user',
        'parts': [
          {
            'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
          },
        ],
      },
    ],
    'generationConfig': {'responseMimeType': 'application/json'},
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
    final List<dynamic>? candidates = decoded['candidates'];
    final Map<String, dynamic>? firstCandidate = candidates?.firstOrNull;
    final Map<String, dynamic>? content = firstCandidate?['content'];
    final List<dynamic>? parts = content?['parts'];
    final String? text = parts?.firstOrNull?['text'];

    if (text == null || text.isEmpty) return null;

    final String cleaned = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
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
