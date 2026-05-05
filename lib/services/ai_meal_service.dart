import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Pass your Gemini API key at build time via --dart-define:
//   flutter run --dart-define=GEMINI_API_KEY=your_key_here
// ---------------------------------------------------------------------------
const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

const String _model = 'gemini-2.0-flash';

const String _systemPrompt =
    'You are a precise macro calculator. Analyze this food image. '
    'Return ONLY a raw, unformatted JSON object. '
    'Do not include markdown code blocks (like ```json). '
    'Do not include any other words, explanations, or text. '
    'The JSON keys must be exactly: "kcal" (integer), "carbs" (integer), '
    '"protein" (integer), "fat" (integer).';

/// Sends [imageBytes] to the Gemini Vision API and returns a macro map with
/// keys `kcal`, `carbs`, `protein`, and `fat`.
///
/// Returns `null` when the request fails or the response cannot be parsed.
Future<Map<String, int>?> analyzeMeal(Uint8List imageBytes) async {
  if (_geminiApiKey.isEmpty) {
    debugPrint(
      'analyzeMeal: GEMINI_API_KEY is not set. '
      'Pass it via --dart-define=GEMINI_API_KEY=<key>.',
    );
    return null;
  }

  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_geminiApiKey',
  );

  final base64Image = base64Encode(imageBytes);

  final body = jsonEncode({
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
  });

  try {
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    final firstCandidate = candidates?.firstOrNull as Map<String, dynamic>?;
    final content = firstCandidate?['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = parts?.firstOrNull?['text'] as String?;

    if (text == null || text.isEmpty) {
      return null;
    }

    // Strip any accidental markdown fences the model may still include.
    final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();

    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    return {
      'kcal': (parsed['kcal'] as num).toInt(),
      'carbs': (parsed['carbs'] as num).toInt(),
      'protein': (parsed['protein'] as num).toInt(),
      'fat': (parsed['fat'] as num).toInt(),
    };
  } catch (e) {
    debugPrint('analyzeMeal error: $e');
    return null;
  }
}
