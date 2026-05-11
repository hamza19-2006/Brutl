import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/secrets.dart';
import '../core/theme/constants/ai_prompts.dart';

@immutable
class AiCoachAttachment {
  const AiCoachAttachment({required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;
}

@immutable
class AiCoachMessage {
  const AiCoachMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.attachmentType,
    this.attachmentData,
  });

  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final String? attachmentType;
  final Map<String, dynamic>? attachmentData;

  bool get isUser => role == 'user';

  AiCoachMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    String? attachmentType,
    Map<String, dynamic>? attachmentData,
  }) {
    return AiCoachMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentData: attachmentData ?? this.attachmentData,
    );
  }

  factory AiCoachMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final timestamp = data['timestamp'];
    DateTime parsedTimestamp;
    if (timestamp is Timestamp) {
      parsedTimestamp = timestamp.toDate();
    } else if (timestamp is DateTime) {
      parsedTimestamp = timestamp;
    } else {
      parsedTimestamp = DateTime.now();
    }

    final rawAttachmentData = data['attachmentData'];
    Map<String, dynamic>? attachmentData;
    if (rawAttachmentData is Map) {
      attachmentData = Map<String, dynamic>.from(rawAttachmentData);
    }

    return AiCoachMessage(
      id: (data['id'] as String?)?.trim().isNotEmpty == true
          ? data['id'] as String
          : doc.id,
      role: data['role'] as String? ?? 'assistant',
      content: data['content'] as String? ?? '',
      timestamp: parsedTimestamp,
      attachmentType: data['attachmentType'] as String?,
      attachmentData: attachmentData,
    );
  }
}

class AiCoachProvider extends ChangeNotifier {
  static const int _pageSize = 20;
  static const int _retentionDays = 14;
  static const int _pruneBatchSize = 400;
  static const String _geminiModel = 'gemini-1.5-flash-latest';
  static const String _grokModel = 'grok-beta';
  static const String _localCacheKeyPrefix = 'ai_coach_messages_';
  static final RegExp _summaryTagPattern = RegExp(
    r'\[\[UPDATE_SUMMARY:\s*([\s\S]*?)\]\]',
    caseSensitive: false,
  );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final http.Client _httpClient;

  AiCoachProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _httpClient = httpClient ?? http.Client();

  List<AiCoachMessage> _messages = const <AiCoachMessage>[];
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _hasMore = true;
  bool _didRunPrune = false;
  String? _error;
  DocumentSnapshot<Map<String, dynamic>>? _oldestLoadedDoc;
  Future<void>? _initialLoadFuture;

  List<AiCoachMessage> get messages =>
      List<AiCoachMessage>.unmodifiable(_messages);
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSending => _isSending;
  bool get hasMore => _hasMore;
  String? get error => _error;

  String? get _uid => _auth.currentUser?.uid;
  String? get _localCacheKey {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return '$_localCacheKeyPrefix$uid';
  }

  CollectionReference<Map<String, dynamic>>? get _messagesCollection {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_coach')
        .doc('messages')
        .collection('messages');
  }

  DocumentReference<Map<String, dynamic>>? get _summaryDocument {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('ai_coach')
        .doc('summary');
  }

  Future<void> initialize() {
    _initialLoadFuture ??= _loadInitialMessages();
    return _initialLoadFuture!;
  }

  Future<void> _loadInitialMessages() async {
    final collection = _messagesCollection;
    if (collection == null) {
      _error = 'You must be signed in to use Elite AI Coach.';
      _messages = const <AiCoachMessage>[];
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
      return;
    }

    _error = null;
    _isLoading = true;
    notifyListeners();

    await _loadMessagesFromLocal();
    notifyListeners();

    try {
      if (!_didRunPrune) {
        await _pruneExpiredMessages();
        _didRunPrune = true;
      }

      final querySnapshot = await collection
          .orderBy('timestamp', descending: true)
          .limit(_pageSize)
          .get();

      final parsed = querySnapshot.docs
          .map(AiCoachMessage.fromDoc)
          .toList(growable: false)
          .reversed
          .toList(growable: false);
      final cutoff = DateTime.now().subtract(
        const Duration(days: _retentionDays),
      );
      final remoteWindow = parsed
          .where((message) => !message.timestamp.isBefore(cutoff))
          .toList(growable: false);
      final remoteLatest = remoteWindow.length <= _pageSize
          ? remoteWindow
          : remoteWindow.sublist(remoteWindow.length - _pageSize);
      final didChange = !_messageListsEquivalent(_messages, remoteLatest);

      if (didChange) {
        _messages = remoteLatest;
      }
      _oldestLoadedDoc = querySnapshot.docs.isEmpty
          ? null
          : querySnapshot.docs.last;
      _hasMore = querySnapshot.docs.length == _pageSize;
      if (didChange) {
        notifyListeners();
        await _saveMessagesToLocal();
      }
    } catch (error) {
      _error = 'Failed to load messages. Please try again.';
      debugPrint('AI_COACH: initial load failed — $error');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _initialLoadFuture = null;
    _isInitialized = false;
    await initialize();
  }

  Future<void> loadOlderMessages() async {
    final collection = _messagesCollection;
    if (collection == null || !_hasMore || _isLoadingMore || _isLoading) {
      return;
    }

    final oldestDoc = _oldestLoadedDoc;
    if (oldestDoc == null) {
      _hasMore = false;
      notifyListeners();
      return;
    }

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final querySnapshot = await collection
          .orderBy('timestamp', descending: true)
          .startAfterDocument(oldestDoc)
          .limit(_pageSize)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _hasMore = false;
      } else {
        final olderChunk = querySnapshot.docs
            .map(AiCoachMessage.fromDoc)
            .toList(growable: false)
            .reversed
            .toList(growable: false);
        _messages = <AiCoachMessage>[...olderChunk, ..._messages];
        _oldestLoadedDoc = querySnapshot.docs.last;
        _hasMore = querySnapshot.docs.length == _pageSize;
        await _saveMessagesToLocal();
      }
    } catch (error) {
      _error = 'Failed to load older messages.';
      debugPrint('AI_COACH: load older failed — $error');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text, {AiCoachAttachment? attachment}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachment == null) return;

    final collection = _messagesCollection;
    final uid = _uid;
    if (collection == null || uid == null || uid.isEmpty) {
      _error = 'You must be signed in to use Elite AI Coach.';
      notifyListeners();
      return;
    }

    _error = null;
    _isSending = true;

    final userDocRef = collection.doc();
    final now = DateTime.now();
    final userMessage = AiCoachMessage(
      id: userDocRef.id,
      role: 'user',
      content: trimmed,
      timestamp: now,
      attachmentType: attachment?.type,
      attachmentData: attachment?.data,
    );

    _messages = <AiCoachMessage>[..._messages, userMessage];
    notifyListeners();

    try {
      await userDocRef.set(_toFirestoreMessageMap(userMessage));
      await _saveMessagesToLocal();

      final assistantText = await _generateAssistantReply(
        latestUserMessage: userMessage,
      );

      final parsed = _parseAssistantReply(assistantText);
      if (parsed.summaryText.isNotEmpty) {
        final summaryDocument = _summaryDocument;
        if (summaryDocument != null) {
          await summaryDocument.set(<String, dynamic>{
            'summary': parsed.summaryText,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      final cleanedAssistantText = parsed.userVisibleText;
      if (cleanedAssistantText.trim().isEmpty) {
        throw StateError('Empty assistant response');
      }

      final assistantDocRef = collection.doc();
      final assistantMessage = AiCoachMessage(
        id: assistantDocRef.id,
        role: 'assistant',
        content: cleanedAssistantText.trim(),
        timestamp: DateTime.now(),
      );

      _messages = <AiCoachMessage>[..._messages, assistantMessage];
      notifyListeners();

      await assistantDocRef.set(_toFirestoreMessageMap(assistantMessage));
      await _saveMessagesToLocal();
    } catch (error) {
      _error = 'Could not send your message right now.';
      debugPrint('AI_COACH: send failed — $error');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _toFirestoreMessageMap(AiCoachMessage message) {
    return <String, dynamic>{
      'id': message.id,
      'role': message.role,
      'content': message.content,
      'timestamp': FieldValue.serverTimestamp(),
      'attachmentType': message.attachmentType,
      'attachmentData': message.attachmentData,
    };
  }

  Future<void> _saveMessagesToLocal() async {
    final cacheKey = _localCacheKey;
    if (cacheKey == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cutoff = DateTime.now().subtract(
        const Duration(days: _retentionDays),
      );
      final retained = _messages
          .where((message) => !message.timestamp.isBefore(cutoff))
          .toList(growable: false);
      final latestWindow = retained.length <= _pageSize
          ? retained
          : retained.sublist(retained.length - _pageSize);

      final payload = latestWindow
          .map(
            (message) => <String, dynamic>{
              'id': message.id,
              'role': message.role,
              'content': message.content,
              'timestamp': message.timestamp.toIso8601String(),
              'attachmentType': message.attachmentType,
              'attachmentData': message.attachmentData,
            },
          )
          .toList(growable: false);

      await prefs.setString(cacheKey, jsonEncode(payload));
    } catch (error) {
      debugPrint('AI_COACH: local save failed — $error');
    }
  }

  Future<void> _loadMessagesFromLocal() async {
    final cacheKey = _localCacheKey;
    if (cacheKey == null) {
      _messages = const <AiCoachMessage>[];
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.trim().isEmpty) {
        _messages = const <AiCoachMessage>[];
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _messages = const <AiCoachMessage>[];
        return;
      }

      final cutoff = DateTime.now().subtract(
        const Duration(days: _retentionDays),
      );
      final parsed = <AiCoachMessage>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final parsedTimestamp = DateTime.tryParse(
          map['timestamp'] as String? ?? '',
        );
        final timestamp = parsedTimestamp ?? DateTime.now();
        if (timestamp.isBefore(cutoff)) continue;

        final rawAttachmentData = map['attachmentData'];
        Map<String, dynamic>? attachmentData;
        if (rawAttachmentData is Map) {
          attachmentData = Map<String, dynamic>.from(rawAttachmentData);
        }

        final rawId = map['id'] as String?;
        parsed.add(
          AiCoachMessage(
            id: rawId != null && rawId.trim().isNotEmpty
                ? rawId
                : 'local_${timestamp.microsecondsSinceEpoch}_${parsed.length}',
            role: map['role'] as String? ?? 'assistant',
            content: map['content'] as String? ?? '',
            timestamp: timestamp,
            attachmentType: map['attachmentType'] as String?,
            attachmentData: attachmentData,
          ),
        );
      }

      parsed.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _messages = parsed.length <= _pageSize
          ? parsed
          : parsed.sublist(parsed.length - _pageSize);
      await _saveMessagesToLocal();
    } catch (error) {
      _messages = const <AiCoachMessage>[];
      debugPrint('AI_COACH: local load failed — $error');
    }
  }

  bool _messageListsEquivalent(
    List<AiCoachMessage> left,
    List<AiCoachMessage> right,
  ) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      final a = left[i];
      final b = right[i];
      if (a.id != b.id ||
          a.role != b.role ||
          a.content != b.content ||
          a.timestamp.compareTo(b.timestamp) != 0 ||
          a.attachmentType != b.attachmentType ||
          !mapEquals(a.attachmentData, b.attachmentData)) {
        return false;
      }
    }
    return true;
  }

  _AssistantReplyParseResult _parseAssistantReply(String text) {
    final match = _summaryTagPattern.firstMatch(text);
    final summaryText = match?.group(1)?.trim() ?? '';
    final cleanedText = text.replaceAll(_summaryTagPattern, '').trim();
    return _AssistantReplyParseResult(
      userVisibleText: cleanedText,
      summaryText: summaryText,
    );
  }

  Future<void> _pruneExpiredMessages() async {
    final collection = _messagesCollection;
    if (collection == null) return;

    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: _retentionDays)),
    );

    while (true) {
      final staleSnapshot = await collection
          .where('timestamp', isLessThan: cutoff)
          .limit(_pruneBatchSize)
          .get();

      if (staleSnapshot.docs.isEmpty) {
        break;
      }

      final batch = _firestore.batch();
      for (final doc in staleSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (staleSnapshot.docs.length < _pruneBatchSize) {
        break;
      }
    }
  }

  Future<String> _generateAssistantReply({
    required AiCoachMessage latestUserMessage,
  }) async {
    final conversation = _buildConversationWindow();
    try {
      final geminiReply = await _generateWithGemini(
        conversation: conversation,
        latestUserMessage: latestUserMessage,
      );
      if (geminiReply != null && geminiReply.trim().isNotEmpty) {
        return geminiReply.trim();
      }
      throw StateError('Gemini returned empty response');
    } catch (error) {
      debugPrint('AI_COACH: Falling back Gemini -> Grok ($error)');
    }

    try {
      final grokReply = await _generateWithGrok(conversation: conversation);
      if (grokReply != null && grokReply.trim().isNotEmpty) {
        return grokReply.trim();
      }
      throw StateError('Grok returned empty response');
    } catch (error) {
      debugPrint('AI_COACH: Falling back Grok -> OpenRouter ($error)');
    }

    try {
      final openRouterReply = await _generateWithOpenRouter(
        conversation: conversation,
      );
      if (openRouterReply != null && openRouterReply.trim().isNotEmpty) {
        return openRouterReply.trim();
      }
      throw StateError('OpenRouter returned empty response');
    } catch (error) {
      debugPrint('AI_COACH: OpenRouter failed — $error');
    }

    return 'Coach is currently offline. Please try again in a moment.';
  }

  List<Map<String, String>> _buildConversationWindow() {
    final window = _messages.length > 14
        ? _messages.sublist(_messages.length - 14)
        : _messages;
    final conversation = <Map<String, String>>[
      <String, String>{
        'role': 'system',
        'content': AiPrompts.eliteCoachSystemPrompt,
      },
    ];

    for (final message in window) {
      final sanitizedRole = message.role == 'user' ? 'user' : 'assistant';
      final body = StringBuffer(message.content.trim());
      if (message.attachmentType != null && message.attachmentData != null) {
        body
          ..writeln()
          ..writeln('[Attachment: ${message.attachmentType}]')
          ..write(jsonEncode(message.attachmentData));
      }
      conversation.add(<String, String>{
        'role': sanitizedRole,
        'content': body.toString().trim(),
      });
    }

    return conversation;
  }

  Future<String?> _generateWithGemini({
    required List<Map<String, String>> conversation,
    required AiCoachMessage latestUserMessage,
  }) async {
    if (geminiApiKeyForAiCoach.trim().isEmpty) {
      return null;
    }

    final transcript = conversation
        .where((entry) => entry['role'] != 'system')
        .map(
          (entry) =>
              '${entry['role'] == 'user' ? 'User' : 'Coach'}: ${entry['content']}',
        )
        .join('\n\n');

    final attachmentContext =
        latestUserMessage.attachmentType == null ||
            latestUserMessage.attachmentData == null
        ? ''
        : '\n\nAttachment (${latestUserMessage.attachmentType}): '
              '${jsonEncode(latestUserMessage.attachmentData)}';

    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  '${AiPrompts.eliteCoachSystemPrompt}\n\nConversation so far:\n$transcript$attachmentContext',
            },
          ],
        },
      ],
      'generationConfig': <String, dynamic>{'temperature': 0.6, 'topP': 0.9},
    };

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$geminiApiKeyForAiCoach',
    );

    try {
      final response = await _httpClient
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        debugPrint('AI_COACH: Gemini HTTP ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      final firstCandidate = candidates.first;
      if (firstCandidate is! Map) return null;
      final content = firstCandidate['content'];
      if (content is! Map) return null;
      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) return null;
      final firstPart = parts.first;
      if (firstPart is! Map) return null;
      return firstPart['text'] as String?;
    } catch (error) {
      debugPrint('AI_COACH: Gemini failed — $error');
      return null;
    }
  }

  Future<String?> _generateWithGrok({
    required List<Map<String, String>> conversation,
  }) async {
    if (grokapikey.trim().isEmpty) {
      return null;
    }

    final payloadMessages = conversation
        .map(
          (entry) => <String, String>{
            'role': entry['role'] == 'assistant' ? 'assistant' : entry['role']!,
            'content': entry['content'] ?? '',
          },
        )
        .toList(growable: false);

    final body = <String, dynamic>{
      'model': _grokModel,
      'messages': payloadMessages,
      'temperature': 0.6,
    };

    try {
      final response = await _httpClient
          .post(
            Uri.parse('https://api.x.ai/v1/chat/completions'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $grokapikey',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        debugPrint('AI_COACH: Grok HTTP ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final firstChoice = choices.first;
      if (firstChoice is! Map) return null;
      final message = firstChoice['message'];
      if (message is! Map) return null;
      return message['content'] as String?;
    } catch (error) {
      debugPrint('AI_COACH: Grok failed — $error');
      return null;
    }
  }

  Future<String?> _generateWithOpenRouter({
    required List<Map<String, String>> conversation,
  }) async {
    if (openRouterApiKey.trim().isEmpty) {
      return null;
    }

    final payloadMessages = conversation
        .map(
          (entry) => <String, String>{
            'role': entry['role'] == 'assistant' ? 'assistant' : entry['role']!,
            'content': entry['content'] ?? '',
          },
        )
        .toList(growable: false);

    final body = <String, dynamic>{
      'model': 'deepseek/deepseek-chat',
      'messages': payloadMessages,
      'temperature': 0.6,
    };

    try {
      final response = await _httpClient
          .post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openRouterApiKey',
              'HTTP-Referer': 'https://github.com/hamza19-2006/Brutl',
              'X-Title': 'Brutl AI Coach',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        debugPrint('AI_COACH: OpenRouter HTTP ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final firstChoice = choices.first;
      if (firstChoice is! Map) return null;
      final message = firstChoice['message'];
      if (message is! Map) return null;
      return message['content'] as String?;
    } catch (error) {
      debugPrint('AI_COACH: OpenRouter failed — $error');
      return null;
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}

class _AssistantReplyParseResult {
  const _AssistantReplyParseResult({
    required this.userVisibleText,
    required this.summaryText,
  });

  final String userVisibleText;
  final String summaryText;
}
