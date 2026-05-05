import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/foundation.dart';

const String _systemPrompt =
    'Analyze this food image. Provide a JSON object with: food_name, calories, protein_g, carbs_g, and fats_g. Do not include any conversational text.';

/// Analyzes a meal image and returns nutritional macros as a JSON-like map.
///
/// Returns `{}` if the model fails or produces an empty/invalid response.
Future<Map<String, dynamic>> analyzeMeal(Uint8List imageBytes) async {
  if (imageBytes.isEmpty) return {};

  try {
    final model = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-3-flash',
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
      ),
    );

    final response = await model.generateContent([
      Content.multi([
        InlineDataPart(_detectImageMimeType(imageBytes), imageBytes),
      ]),
    ]);

    final raw = response.text;
    if (raw == null || raw.trim().isEmpty) {
      debugPrint('MEAL_AI: Empty response text');
      return {};
    }

    final decoded = jsonDecode(_extractJsonObject(raw));
    if (decoded is Map) {
      return _normalizeMacrosMap(Map<String, dynamic>.from(decoded));
    }

    debugPrint('MEAL_AI: Expected JSON object but got ${decoded.runtimeType}');
    return {};
  } on FormatException catch (e) {
    debugPrint('MEAL_AI: JSON parse error — $e');
    return {};
  } catch (e) {
    // firebase_vertexai can throw FirebaseException; we keep this broad so callers
    // don’t need to worry about AI/network/provider errors.
    debugPrint('MEAL_AI: analyzeMeal failed — $e');
    return {};
  }
}

String _extractJsonObject(String text) {
  final trimmed = text.trim();

  // Handle common formatting like ```json ... ```
  final start = trimmed.indexOf('{');
  final end = trimmed.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) {
    // Let jsonDecode throw a FormatException with the original text.
    return trimmed;
  }
  return trimmed.substring(start, end + 1);
}

Map<String, dynamic> _normalizeMacrosMap(Map<String, dynamic> map) {
  return <String, dynamic>{
    'food_name': (map['food_name'] ?? '').toString(),
    'calories': _asNum(map['calories']),
    'protein_g': _asNum(map['protein_g']),
    'carbs_g': _asNum(map['carbs_g']),
    'fats_g': _asNum(map['fats_g']),
  };
}

String _detectImageMimeType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }

  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }

  // Most image pickers deliver either JPEG or PNG. Defaulting to JPEG keeps the API happy.
  return 'image/jpeg';
}

num? _asNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) {
    return num.tryParse(value.trim());
  }
  return null;
}
