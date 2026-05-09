import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import 'share_meal_screen.dart';
import 'share_workout_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key, required this.friend});
  final FriendModel friend;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final String _chatId;
  late final String _myUid;
  Timer? _typingDebounce;
  bool _isTyping = false;
  bool _isMarkingRead = false;
  String _lastUnreadSignature = '';

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _chatId = buildChatId(_myUid, widget.friend.uid);
    unawaited(context.read<ChatProvider>().markChatAsRead(_chatId));
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    unawaited(context.read<ChatProvider>().setTypingStatus(_chatId, false));
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _typingDebounce?.cancel();
    if (_isTyping) {
      _isTyping = false;
      unawaited(context.read<ChatProvider>().setTypingStatus(_chatId, false));
    }
    context.read<ChatProvider>().sendTextMessage(_chatId, text);
    _controller.clear();
    _scrollToBottom();
  }

  void _onInputChanged(String value) {
    if (value.trim().isEmpty) {
      _typingDebounce?.cancel();
      if (_isTyping) {
        _isTyping = false;
        unawaited(context.read<ChatProvider>().setTypingStatus(_chatId, false));
      }
      return;
    }

    if (!_isTyping) {
      _isTyping = true;
      unawaited(context.read<ChatProvider>().setTypingStatus(_chatId, true));
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        unawaited(context.read<ChatProvider>().setTypingStatus(_chatId, false));
      }
    });
  }

  void _markAsReadIfNeeded(List<MessageModel> messages) {
    final unreadIncoming = messages
        .where((m) => m.senderId != _myUid && m.status != 'read')
        .toList();
    if (unreadIncoming.isEmpty) return;
    final signature = '${unreadIncoming.length}_${unreadIncoming.last.id}';
    if (_isMarkingRead || signature == _lastUnreadSignature) return;
    _isMarkingRead = true;
    _lastUnreadSignature = signature;
    unawaited(
      context.read<ChatProvider>().markChatAsRead(_chatId).whenComplete(() {
        _isMarkingRead = false;
      }),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAttachmentSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusLarge),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AttachOption(
                icon: Icons.restaurant_rounded,
                label: 'Share Meal',
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToMealSelector();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _AttachOption(
                icon: Icons.fitness_center_rounded,
                label: 'Share Workout',
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToWorkoutSelector();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToMealSelector() async {
    final payload = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => const ShareMealScreen(),
      ),
    );
    if (payload != null && mounted) {
      context.read<ChatProvider>().sendWidgetMessage(
        _chatId,
        'meal_share',
        payload,
      );
      _scrollToBottom();
    }
  }

  Future<void> _navigateToWorkoutSelector() async {
    final payload = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => const ShareWorkoutScreen(),
      ),
    );
    if (payload != null && mounted) {
      context.read<ChatProvider>().sendWidgetMessage(
        _chatId,
        'exercise_share',
        payload,
      );
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.friend.resolvedName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headingMedium().copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '@${widget.friend.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall(color: AppColors.textTertiary),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: chatProvider.chatMetaStream(_chatId),
        builder: (context, chatSnap) {
          final chatData = chatSnap.data?.data() ?? const <String, dynamic>{};
          final isFriendTyping =
              (chatData['isTyping_${widget.friend.uid}'] as bool?) ?? false;

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: chatProvider.messagesStream(_chatId),
                  builder: (ctx, snap) {
                    final serverMessages = snap.data ?? [];
                    _markAsReadIfNeeded(serverMessages);
                    final serverIds = serverMessages.map((m) => m.id).toSet();
                    final optimistic = chatProvider.optimisticMessages
                        .where((m) => !serverIds.contains(m.id))
                        .toList();
                    final allMessages = [...serverMessages, ...optimistic];

                    if (allMessages.isEmpty) {
                      return Center(
                        child: Text(
                          'No messages yet. Say hello!',
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: allMessages.length,
                      itemBuilder: (ctx, i) {
                        final msg = allMessages[i];
                        final isMe = msg.senderId == _myUid;
                        return _MessageBubble(message: msg, isMe: isMe);
                      },
                    );
                  },
                ),
              ),
              if (isFriendTyping)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    'Typing...',
                    style: AppTextStyles.labelSmall(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              _InputBar(
                controller: _controller,
                onSend: _send,
                onAttach: _showAttachmentSheet,
                onChanged: _onInputChanged,
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// Message bubble
// =============================================================================

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({required this.message, required this.isMe});
  final MessageModel message;
  final bool isMe;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;
    final isTextMessage = message.type == 'text';

    Widget content;
    switch (message.type) {
      case 'meal_share':
        content = _MealShareBubble(payload: message.payload, isMe: isMe);
        break;
      case 'exercise_share':
        content = _ExerciseShareBubble(payload: message.payload, isMe: isMe);
        break;
      default:
        content = Text(
          message.payload['text'] as String? ?? '',
          style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
        );
    }

    final bubbleColor = isMe
        ? AppColors.accentPrimary
        : const Color(0xFF171A1F);
    final bubbleRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => setState(() => _showDetails = !_showDetails),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: isTextMessage
                    ? const EdgeInsets.all(AppSpacing.md)
                    : null,
                decoration: isTextMessage
                    ? BoxDecoration(
                        color: bubbleColor,
                        border: Border.all(
                          color: isMe
                              ? AppColors.accentSecondary
                              : AppColors.borderStrong,
                        ),
                        borderRadius: bubbleRadius,
                      )
                    : null,
                child: isTextMessage
                    ? content
                    : SizedBox(width: double.infinity, child: content),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _showDetails
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _MessageDetails(message: message, isMe: isMe),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageDetails extends StatelessWidget {
  const _MessageDetails({required this.message, required this.isMe});

  final MessageModel message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final sentTime = DateFormat.jm().format(message.timestamp);
    final detailStyle = AppTextStyles.labelSmall(
      color: AppColors.textTertiary.withValues(alpha: 0.9),
    );

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          isMe ? 'Sent: $sentTime' : 'Received: $sentTime',
          style: detailStyle,
        ),
        if (isMe && message.status == 'read' && message.readAt != null)
          Text(
            'Seen: ${DateFormat.jm().format(message.readAt!)}',
            style: detailStyle,
          ),
      ],
    );
  }
}

// =============================================================================
// Meal share bubble
// =============================================================================

class _MealShareBubble extends StatelessWidget {
  const _MealShareBubble({required this.payload, required this.isMe});
  final Map<String, dynamic> payload;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final mealName = payload['mealName'] as String? ?? 'Meal';
    final calories = payload['calories'] as num? ?? 0;
    final protein = payload['protein'] as num? ?? 0;
    final carbs = payload['carbs'] as num? ?? 0;
    final fats = payload['fats'] as num? ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF14181D),
        border: Border.all(
          color: isMe ? AppColors.borderAccent : AppColors.borderSubtle,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant,
                color: AppColors.accentPrimary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  mealName,
                  style: AppTextStyles.headingSmall(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MacroPill(
                label: 'Protein',
                value: '${protein}g',
                color: AppColors.statusSuccess,
              ),
              _MacroPill(
                label: 'Carbs',
                value: '${carbs}g',
                color: AppColors.statusInfo,
              ),
              _MacroPill(
                label: 'Fats',
                value: '${fats}g',
                color: AppColors.statusWarning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                'Total Calories',
                style: AppTextStyles.labelSmall(color: AppColors.textTertiary),
              ),
              const Spacer(),
              Text(
                '${calories.toStringAsFixed(calories % 1 == 0 ? 0 : 1)} kcal',
                style: AppTextStyles.headingSmall(
                  color: AppColors.accentPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundQuaternary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.labelSmall(color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.labelLarge(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Exercise share bubble
// =============================================================================

String _formatReps(dynamic reps) {
  if (reps == null) return '-';
  if (reps is num || reps is String) return reps.toString();

  if (reps is Map) {
    final map = Map<String, dynamic>.from(reps);
    final min = map['min'] ?? map['minReps'] ?? map['from'];
    final max = map['max'] ?? map['maxReps'] ?? map['to'];
    if (min != null && max != null) return '$min - $max';
    return (min ?? max)?.toString() ?? '-';
  }

  return '-';
}

String _formatSets(dynamic sets) {
  if (sets == null) return '-';
  return sets.toString();
}

class _ExerciseShareBubble extends StatelessWidget {
  const _ExerciseShareBubble({required this.payload, required this.isMe});
  final Map<String, dynamic> payload;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final scope = payload['shareScope'] as String? ?? 'day';
    final title =
        payload['title'] as String? ?? payload['name'] as String? ?? 'Workout';
    final exercises = (payload['exercises'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final IconData headerIcon;
    final Widget body;

    switch (scope) {
      case 'week':
        headerIcon = Icons.calendar_month;
        final days = (payload['days'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        body = _WeekBody(days: days);
      case 'exercise':
        headerIcon = Icons.sports_gymnastics;
        final sets = exercises.isNotEmpty ? exercises[0]['sets'] : null;
        final reps = exercises.isNotEmpty ? exercises[0]['reps'] : null;
        body = _ExerciseBody(sets: sets, reps: reps);
      default:
        headerIcon = Icons.fitness_center_rounded;
        body = _DayBody(exercises: exercises);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(
          color: isMe ? AppColors.borderAccent : AppColors.borderDefault,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon, color: AppColors.accentPrimary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headingSmall(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          body,
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: AppColors.backgroundQuaternary,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
              splashColor: AppColors.accentGlow,
              highlightColor: AppColors.accentSoft.withValues(alpha: 0.45),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderAccent),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusSmall,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Save to My Plan',
                    style: AppTextStyles.labelLarge(
                      color: AppColors.accentPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Week scope body ──────────────────────────────────────────────────────────

class _WeekBody extends StatelessWidget {
  const _WeekBody({required this.days});
  final List<String> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Text(
        'No days in this program',
        style: AppTextStyles.labelSmall(color: AppColors.textTertiary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.circle,
                  color: AppColors.accentPrimary,
                  size: 5,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    day,
                    style: AppTextStyles.bodySmall(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Day scope body ───────────────────────────────────────────────────────────

class _DayBody extends StatelessWidget {
  const _DayBody({required this.exercises});
  final List<Map<String, dynamic>> exercises;

  @override
  Widget build(BuildContext context) {
    final preview = exercises.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${exercises.length} Exercise${exercises.length == 1 ? '' : 's'}',
          style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
        ),
        if (preview.isNotEmpty) const SizedBox(height: 6),
        for (final ex in preview)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              ex['exerciseName'] as String? ?? '',
              style: AppTextStyles.labelSmall(color: AppColors.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (exercises.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+ ${exercises.length - 3} more',
              style: AppTextStyles.labelSmall(color: AppColors.textTertiary),
            ),
          ),
      ],
    );
  }
}

// ─── Exercise scope body ──────────────────────────────────────────────────────

class _ExerciseBody extends StatelessWidget {
  const _ExerciseBody({required this.sets, required this.reps});
  final dynamic sets;
  final dynamic reps;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _MacroPill(
          label: 'Sets',
          value: _formatSets(sets),
          color: AppColors.accentPrimary,
        ),
        _MacroPill(
          label: 'Reps',
          value: _formatReps(reps),
          color: AppColors.statusInfo,
        ),
      ],
    );
  }
}

// =============================================================================
// Input bar
// =============================================================================

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment "+"
            InkWell(
              onTap: onAttach,
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.backgroundTertiary,
                  border: Border.all(color: AppColors.borderDefault),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusSmall,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.accentPrimary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AppTextStyles.bodyMedium(
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundTertiary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusSmall,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.borderDefault,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusSmall,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.borderDefault,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusSmall,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.accentPrimary,
                    ),
                  ),
                ),
                onSubmitted: (_) => onSend(),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            InkWell(
              onTap: onSend,
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusSmall,
                  ),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Attachment option button
// =============================================================================

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundTertiary,
          border: Border.all(color: AppColors.borderDefault),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentPrimary, size: 24),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: AppTextStyles.headingSmall()),
          ],
        ),
      ),
    );
  }
}
