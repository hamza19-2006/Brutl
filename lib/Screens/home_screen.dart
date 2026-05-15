import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/secrets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/constants/ai_prompts.dart';
import '../providers/health_provider.dart';
import '../providers/nutrition_service.dart';
import '../providers/workout_nutrition_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/biometric_card.dart';
import 'calories_history_screen.dart';
import 'chat/chat_list_screen.dart';
import 'home/home_screen_ex_show.dart';
import 'shop/shop_main_screen.dart';
import 'steps_history_screen.dart';
import 'workout_screen.dart';

// ─── AI Coach models (kept here so nothing else needs to import them) ─────────

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
      _messages = parsed;
      _oldestLoadedDoc = querySnapshot.docs.isEmpty
          ? null
          : querySnapshot.docs.last;
      _hasMore = querySnapshot.docs.length == _pageSize;
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
      if (staleSnapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in staleSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (staleSnapshot.docs.length < _pruneBatchSize) break;
    }
  }

  Future<String> _generateAssistantReply({
    required AiCoachMessage latestUserMessage,
  }) async {
    final conversation = _buildConversationWindow();
    final geminiReply = await _generateWithGemini(
      conversation: conversation,
      latestUserMessage: latestUserMessage,
    );
    if (geminiReply != null && geminiReply.trim().isNotEmpty) {
      return geminiReply;
    }
    final grokReply = await _generateWithGrok(conversation: conversation);
    if (grokReply != null && grokReply.trim().isNotEmpty) {
      return grokReply;
    }
    throw StateError('All AI providers failed');
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
    if (geminiApiKeyForAiCoach.trim().isEmpty) return null;
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
      if (response.statusCode != 200) return null;
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
    if (grokapikey.trim().isEmpty) return null;
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
      if (response.statusCode != 200) return null;
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

// ─── HomeScreen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _HomeTab(),
          WorkoutScreen(showBottomNavigationBar: false),
          ShopMainScreen(),
          ChatListScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

// ─── Bottom Navigation ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      BottomNavigationBarItem(
        icon: Icon(Icons.fitness_center_rounded),
        label: 'Workout',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.shopping_bag_rounded),
        label: 'Shop',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_rounded),
        label: 'Chat',
      ),
    ];

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF111111),
      selectedItemColor: const Color(0xFFFF3D00),
      unselectedItemColor: const Color(0xFF5A5A5A),
      selectedFontSize: 10,
      unselectedFontSize: 10,
      elevation: 0,
      items: items,
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HomeHeader()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _StatsRow()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _SectionLabel('Today\'s Targets')),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: HomeScreenExShow()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final stepProvider = context.watch<StepProvider>();
    final now = DateTime.now();

    final hour = now.hour;
    final greeting = hour >= 5 && hour < 12
        ? 'Good Morning'
        : hour >= 12 && hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    final todayIndex = now.weekday - 1;
    final splitDays = workoutProvider.customSplitDays;
    final inBounds = todayIndex >= 0 && todayIndex < splitDays.length;
    final todayName = inBounds ? splitDays[todayIndex] : 'Rest Day';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: greeting + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, snap) {
                    String name = workoutProvider.user.name;
                    if (snap.hasData && snap.data!.exists) {
                      final data = snap.data!.data() as Map<String, dynamic>;
                      final dn =
                          (data['display_name'] as String?)?.trim() ?? '';
                      final un = (data['username'] as String?)?.trim() ?? '';
                      if (dn.isNotEmpty)
                        name = dn;
                      else if (un.isNotEmpty)
                        name = un;
                    }
                    return Text(
                      '$greeting, $name ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('EEEE, d MMMM y').format(now),
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Text(
                      todayName,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right: brand + calories
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFFF3D00),
                    size: 28,
                  ),
                  const SizedBox(width: 2),
                  const Text(
                    'Brutl',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Consumer<StepProvider>(
                builder: (context, liveStepProvider, _) {
                  // MODULE 1 FIX — read the strictly-computed steps so the
                  // calorie text can never derive from the raw hardware
                  // counter (e.g. 20,836 → 833 kcal).
                  final fallbackCalories =
                      workoutProvider.currentDailyCaloriesBurned;
                  final liveCalories = liveStepProvider.todaysDisplaySteps > 0
                      ? liveStepProvider.caloriesBurned
                      : (stepProvider.todaysDisplaySteps > 0
                            ? stepProvider.caloriesBurned
                            : fallbackCalories);
                  return Text(
                    'kcal ${liveCalories.round()} 🔥',
                    style: const TextStyle(
                      color: Color(0xFFD0D0D0),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row (Steps + Calories cards) ──────────────────────────────────────

// BUG 4 FIX: Changed from StatelessWidget to StatefulWidget so the
// CaloriesCard can subscribe to NutritionService for consumed calories
// instead of showing burned calories from StepProvider.
class _StatsRow extends StatefulWidget {
  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  int _caloriesEaten = 0;
  int _calorieGoal = 0;
  StreamSubscription<NutritionData>? _nutritionSub;

  @override
  void initState() {
    super.initState();
    _loadNutrition();
  }

  Future<void> _loadNutrition() async {
    // Seed from WorkoutProvider's goal so the circle isn't empty on first paint.
    final workoutProvider = context.read<WorkoutProvider>();
    final goalFromProfile = workoutProvider.user.dailyCalorieGoal;
    if (goalFromProfile > 0 && mounted) {
      setState(() => _calorieGoal = goalFromProfile);
    }

    final data = await NutritionService.instance.loadTodayNutrition();
    if (!mounted) return;
    setState(() {
      _caloriesEaten = data.caloriesEaten;
      _calorieGoal = data.calorieGoal > 0 ? data.calorieGoal : _calorieGoal;
    });

    _nutritionSub = NutritionService.instance.stream.listen((data) {
      if (!mounted) return;
      setState(() {
        _caloriesEaten = data.caloriesEaten;
        _calorieGoal = data.calorieGoal > 0 ? data.calorieGoal : _calorieGoal;
      });
    });
  }

  @override
  void dispose() {
    _nutritionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WorkoutProvider, StepProvider>(
      builder: (context, workoutProvider, stepProvider, _) {
        final stepGoal = workoutProvider.user.dailyStepGoal;
        // MODULE 1 FIX — always read the computed `todaysDisplaySteps`
        // (raw hardware counter − daily baseline). Never bind the UI to
        // raw pedometer events.
        final liveSteps = stepProvider.todaysDisplaySteps > 0
            ? stepProvider.todaysDisplaySteps
            : workoutProvider.currentDailySteps;
        final steps = liveSteps < 0 ? 0 : liveSteps;
        final progress = stepGoal > 0
            ? (steps / stepGoal).clamp(0.0, 1.0).toDouble()
            : 0.0;

        // BUG 4 FIX: Use consumed calories from NutritionService
        // instead of burned calories from StepProvider.
        final consumedCalories = _caloriesEaten.toDouble();
        final calorieGoal = _calorieGoal > 0
            ? _calorieGoal
            : workoutProvider.user.dailyCalorieGoal;
        final calProgress = calorieGoal > 0
            ? (consumedCalories / calorieGoal).clamp(0.0, 1.0)
            : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: StepsCard(
                    currentSteps: steps,
                    goalSteps: stepGoal,
                    progress: progress,
                    stepsLabel: 'Steps',
                    stepsUnitLabel: 'steps today',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: CaloriesCard(
                    caloriesBurned: consumedCalories,
                    calorieGoal: calorieGoal,
                    progress: calProgress,
                    caloriesLabel: 'Calories',
                    caloriesUnitLabel: 'kcal eaten',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CaloriesHistoryScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Shop Placeholder ─────────────────────────────────────────────────────────

class _ShopPlaceholder extends StatelessWidget {
  const _ShopPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_rounded,
              color: Color(0xFF333333),
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Shop Coming Soon',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
