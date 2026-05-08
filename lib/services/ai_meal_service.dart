import 'dart:convert';
import '../config/secrets.dart'; // Ensure openRouterApiKey is added here

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

// API Config
const String _geminiApiKey = geminiApiKey;
const String _openRouterApiKey =
    openRouterApiKey; // Add this to your secrets.dart

// Model IDs
const String _geminiModel = 'gemini-flash-latest';
const String _gptModel = 'openai/gpt-4o-mini';

const String _systemPrompt =
    'You are a precise macro calculator. Analyze this food image. '
    'Return ONLY a raw, unformatted JSON object. '
    'The JSON keys must be exactly: "kcal", "carbs", "protein", "fat". '
    'All values must be integers.';

Future<Map<String, int>?> analyzeMeal(Uint8List imageBytes) async {
  // 1. --- IMAGE COMPRESSION & OPTIMIZATION ---
  Uint8List optimizedBytes = imageBytes;
  try {
    img.Image? decodedImage = img.decodeImage(imageBytes);
    if (decodedImage != null) {
      img.Image resized = (decodedImage.width > decodedImage.height)
          ? img.copyResize(decodedImage, width: 800)
          : img.copyResize(decodedImage, height: 800);

      optimizedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
      debugPrint(
        '--- [IMAGE] Optimized to: ${(optimizedBytes.lengthInBytes / 1024).toStringAsFixed(2)} KB ---',
      );
    }
  } catch (e) {
    debugPrint('--- [IMAGE] Optimization failed: $e ---');
  }

  // 2. --- TRY PRIMARY MODEL (GEMINI) ---
  var result = await _attemptGemini(optimizedBytes);
  if (result != null) return result;

  // 3. --- FALLBACK: TRY SECONDARY MODEL (GPT-4O-MINI) ---
  debugPrint(
    '--- [AI SCAN] Gemini failed. Attempting GPT-4o-mini Fallback... ---',
  );
  return await _attemptGPTMini(optimizedBytes);
}

/// Primary Scan using Gemini 1.5 Flash
Future<Map<String, int>?> _attemptGemini(Uint8List bytes) async {
  if (_geminiApiKey.isEmpty) return null;

  final String url =
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiApiKey';
  final String base64Image = base64Encode(bytes);

  final body = {
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
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return _parseResponse(response.body, isGemini: true);
    }
    debugPrint('--- [GEMINI] Failed with status: ${response.statusCode} ---');
  } catch (e) {
    debugPrint('--- [GEMINI] Exception: $e ---');
  }
  return null;
}

/// Fallback Scan using GPT-4o-mini via OpenRouter
Future<Map<String, int>?> _attemptGPTMini(Uint8List bytes) async {
  if (_openRouterApiKey.isEmpty) return null;

  final String url = 'https://openrouter.ai/api/v1/chat/completions';
  final String base64Image = base64Encode(bytes);

  final body = {
    "model": _gptModel,
    "messages": [
      {
        "role": "user",
        "content": [
          {"type": "text", "text": _systemPrompt},
          {
            "type": "image_url",
            "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
            "detail": "low",
          },
        ],
      },
    ],
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openRouterApiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return _parseResponse(response.body, isGemini: false);
    }
    debugPrint('--- [GPT-MINI] Failed with status: ${response.statusCode} ---');
  } catch (e) {
    debugPrint('--- [GPT-MINI] Exception: $e ---');
  }
  return null;
}

/// Helper to clean and parse JSON from both AI formats
Map<String, int>? _parseResponse(
  String responseBody, {
  required bool isGemini,
}) {
  try {
    final Map<String, dynamic> decoded = jsonDecode(responseBody);
    String? text;

    if (isGemini) {
      text = decoded['candidates']?[0]['content']?['parts']?[0]['text'];
    } else {
      text = decoded['choices']?[0]['message']?['content'];
    }

    if (text == null) return null;

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
    debugPrint('--- [PARSING] Error: $e ---');
    return null;
  }
}
