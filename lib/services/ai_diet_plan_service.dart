import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

const String _deepSeekModel = 'deepseek-v4-flash';

Future<String?> generateAiPlan({
  required String systemPrompt,
  required String userPrompt,
}) async {
  const apiKey = openRouterApiKey;
  if (apiKey.isEmpty) {
    debugPrint('[AI_PLAN] OpenRouter API key not set.');
    return null;
  }

  try {
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
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      debugPrint('[AI_PLAN] OpenRouter HTTP ${response.statusCode}');
      return null;
    }

    final text =
        jsonDecode(response.body)['choices']?[0]['message']?['content']
            as String?;
    return text;
  } catch (e) {
    debugPrint('[AI_PLAN] OpenRouter exception: $e');
    return null;
  }
}
