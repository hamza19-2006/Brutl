import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AI TEXT MEAL SERVICE — 2-Tier Fallback: Gemini → DeepSeek V4 flash
// ═══════════════════════════════════════════════════════════════════════════════

const String _systemPrompt =
    'Estimate macros for this food text. '
    'Return ONLY raw JSON: {"kcal": 0, "carbs": 0, "protein": 0, "fat": 0}. '
    'All values must be integers. No markdown, no explanations.';

const String _geminiModel = 'gemini-1.5-flash-latest';
const String _deepSeekModel = 'deepseek-v4-flash';

/// Analyzes a plain-text food description and returns macro estimates.
/// Tries Gemini 1.5 Flash first, then DeepSeek V4 flash via OpenRouter.
/// Returns null if both fail.
Future<Map<String, int>?> analyzeTextMeal(String foodDescription) async {
  if (foodDescription.trim().isEmpty) return null;

  debugPrint('[AI_TEXT] Analyzing: "$foodDescription"');

  // Tier 1: Gemini 1.5 Flash
  final geminiResult = await _attemptGemini(foodDescription);
  if (geminiResult != null) {
    debugPrint('[AI_TEXT] Gemini succeeded.');
    return geminiResult;
  }

  // Tier 2: DeepSeek V4 flash via OpenRouter
  debugPrint('[AI_TEXT] Gemini failed — trying DeepSeek V4 flash ...');
  final deepSeekResult = await _attemptDeepSeek(foodDescription);
  if (deepSeekResult != null) {
    debugPrint('[AI_TEXT] DeepSeek V4 flash succeeded.');
    return deepSeekResult;
  }

  debugPrint('[AI_TEXT] All providers failed.');
  return null;
}

// ─── Tier 1: Gemini 1.5 Flash ────────────────────────────────────────────────

Future<Map<String, int>?> _attemptGemini(String food) async {
  const apiKey = geminiApiKey1;
  if (apiKey.isEmpty) {
    debugPrint('[AI_TEXT] Gemini API key not set — skipping.');
    return null;
  }

  try {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$apiKey';

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': '$_systemPrompt\n\nFood: $food'},
                ],
              },
            ],
            'generationConfig': {'temperature': 0.1},
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      debugPrint('[AI_TEXT] Gemini HTTP ${response.statusCode}');
      return null;
    }

    final text =
        jsonDecode(
              response.body,
            )['candidates']?[0]['content']?['parts']?[0]['text']
            as String?;
    return _parseJsonResponse(text);
  } catch (e) {
    debugPrint('[AI_TEXT] Gemini exception: $e');
    return null;
  }
}

// ─── Tier 2: DeepSeek V4 flash via OpenRouter ──────────────────────────────────────

Future<Map<String, int>?> _attemptDeepSeek(String food) async {
  const apiKey = openRouterApiKey;
  if (apiKey.isEmpty) {
    debugPrint('[AI_TEXT] OpenRouter API key not set — skipping.');
    return null;
  }

  try {
    final response = await http
        .post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': _deepSeekModel,
            'messages': [
              {'role': 'system', 'content': _systemPrompt},
              {'role': 'user', 'content': food},
            ],
            'temperature': 0.1,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      debugPrint('[AI_TEXT] DeepSeek V4 flash HTTP ${response.statusCode}');
      return null;
    }

    final text =
        jsonDecode(response.body)['choices']?[0]['message']?['content']
            as String?;
    return _parseJsonResponse(text);
  } catch (e) {
    debugPrint('[AI_TEXT] DeepSeek V4 flash exception: $e');
    return null;
  }
}

// ─── JSON Parser ─────────────────────────────────────────────────────────────

Map<String, int>? _parseJsonResponse(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;

    final parsed =
        jsonDecode(cleaned.substring(start, end + 1)) as Map<String, dynamic>;

    return {
      'kcal': (parsed['kcal'] as num?)?.toInt() ?? 0,
      'carbs': (parsed['carbs'] as num?)?.toInt() ?? 0,
      'protein': (parsed['protein'] as num?)?.toInt() ?? 0,
      'fat': (parsed['fat'] as num?)?.toInt() ?? 0,
    };
  } catch (e) {
    debugPrint('[AI_TEXT] JSON parse error: $e  raw="$raw"');
    return null;
  }
}
