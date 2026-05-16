import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

const String _deepSeekModel = 'deepseek-v4-flash';
const int _maxRetries = 2;

Future<String?> generateAiPlan({
  required String systemPrompt,
  required String userPrompt,
}) async {
  const apiKey = openRouterApiKey;
  if (apiKey.isEmpty) {
    debugPrint('[AI_PLAN] OpenRouter API key not set.');
    return null;
  }

  for (int attempt = 1; attempt <= _maxRetries; attempt++) {
    try {
      debugPrint('[AI_PLAN] Attempt $attempt/$_maxRetries ...');
      final response = await http
          .post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'X-Title': 'Brutl AI Plan',
            },
            body: jsonEncode({
              'model': _deepSeekModel,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': 0.4,
              'max_tokens': 16000,
            }),
          )
          .timeout(const Duration(seconds: 180));

      if (response.statusCode != 200) {
        debugPrint('[AI_PLAN] OpenRouter HTTP ${response.statusCode}');
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        return null;
      }

      final text =
          jsonDecode(response.body)['choices']?[0]['message']?['content']
              as String?;
      if (text != null && text.trim().isNotEmpty) {
        debugPrint('[AI_PLAN] Success on attempt $attempt.');
        return text;
      }
      if (attempt < _maxRetries) {
        await Future.delayed(const Duration(seconds: 3));
        continue;
      }
      return null;
    } catch (e) {
      debugPrint('[AI_PLAN] OpenRouter exception (attempt $attempt): $e');
      if (attempt < _maxRetries) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }
  return null;
}
