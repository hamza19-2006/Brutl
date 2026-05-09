import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _chatId = buildChatId(_myUid, widget.friend.uid);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatProvider>().sendTextMessage(_chatId, text);
    _controller.clear();
    _scrollToBottom();
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
      context
          .read<ChatProvider>()
          .sendWidgetMessage(_chatId, 'meal_share', payload);
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
      context
          .read<ChatProvider>()
          .sendWidgetMessage(_chatId, 'exercise_share', payload);
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
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.backgroundQuaternary,
              backgroundImage: widget.friend.photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(widget.friend.photoUrl)
                  : null,
              child: widget.friend.photoUrl.isEmpty
                  ? const Icon(Icons.person,
                      color: AppColors.textTertiary, size: 16)
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                widget.friend.resolvedName,
                style: AppTextStyles.headingMedium(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: chatProvider.messagesStream(_chatId),
              builder: (ctx, snap) {
                final serverMessages = snap.data ?? [];
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
                          color: AppColors.textTertiary),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent);
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

          // Input area
          _InputBar(
            controller: _controller,
            onSend: _send,
            onAttach: _showAttachmentSheet,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Message bubble
// =============================================================================

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});
  final MessageModel message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat.jm().format(message.timestamp);
    final isTextMessage = message.type == 'text';

    Widget content;
    switch (message.type) {
      case 'meal_share':
        content = _MealShareBubble(payload: message.payload, isMe: isMe);
        break;
      case 'exercise_share':
        content =
            _ExerciseShareBubble(payload: message.payload, isMe: isMe);
        break;
      default:
        content = Text(message.payload['text'] as String? ?? '',
            style: AppTextStyles.bodyMedium(color: AppColors.textPrimary));
    }

    final bubbleColor =
        isMe ? AppColors.accentPrimary : const Color(0xFF171A1F);
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
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: isTextMessage ? const EdgeInsets.all(AppSpacing.md) : null,
        decoration: isTextMessage
            ? BoxDecoration(
                color: bubbleColor,
                border: Border.all(
                  color:
                      isMe ? AppColors.accentSecondary : AppColors.borderStrong,
                ),
                borderRadius: bubbleRadius,
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            isTextMessage
                ? content
                : SizedBox(width: double.infinity, child: content),
            const SizedBox(height: AppSpacing.xs),
            Text(
              timeStr,
              style: AppTextStyles.labelSmall(
                color: isTextMessage
                    ? AppColors.textPrimary.withValues(alpha: 0.78)
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
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
              const Icon(Icons.restaurant,
                  color: AppColors.accentPrimary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  mealName,
                  style: AppTextStyles.headingSmall(color: AppColors.textPrimary),
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
                style:
                    AppTextStyles.headingSmall(color: AppColors.accentPrimary),
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
          Text(label,
              style: AppTextStyles.labelSmall(color: AppColors.textSecondary)),
          const SizedBox(width: AppSpacing.xs),
          Text(value,
              style: AppTextStyles.labelLarge(color: AppColors.textPrimary)),
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
    final name = payload['name'] as String? ?? 'Workout';
    final exercises = (payload['exercises'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

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
              const Icon(Icons.fitness_center_rounded,
                  color: AppColors.accentPrimary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyles.headingSmall(color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < exercises.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle,
                      color: AppColors.textTertiary, size: 7),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercises[i]['exerciseName'] as String? ?? 'Exercise',
                        style:
                            AppTextStyles.bodySmall(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatSets(exercises[i]['sets'])} Sets • ${_formatReps(exercises[i]['reps'])} Reps',
                        style: AppTextStyles.labelSmall(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i != exercises.length - 1) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          if (exercises.isEmpty)
            Text(
              'No exercise details provided',
              style: AppTextStyles.labelSmall(color: AppColors.textTertiary),
            ),
          const SizedBox(height: AppSpacing.md),
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
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusSmall),
                ),
                child: Center(
                  child: Text(
                    'Save to My Split',
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

// =============================================================================
// Input bar
// =============================================================================

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          top: BorderSide(color: AppColors.borderDefault),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment "+"
            InkWell(
              onTap: onAttach,
              borderRadius:
                  BorderRadius.circular(AppSpacing.borderRadiusSmall),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.backgroundTertiary,
                  border: Border.all(color: AppColors.borderDefault),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusSmall),
                ),
                child: const Icon(Icons.add_rounded,
                    color: AppColors.accentPrimary, size: 22),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                style:
                    AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AppTextStyles.bodyMedium(
                      color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundTertiary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusSmall),
                    borderSide:
                        const BorderSide(color: AppColors.borderDefault),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusSmall),
                    borderSide:
                        const BorderSide(color: AppColors.borderDefault),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusSmall),
                    borderSide:
                        const BorderSide(color: AppColors.accentPrimary),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            InkWell(
              onTap: onSend,
              borderRadius:
                  BorderRadius.circular(AppSpacing.borderRadiusSmall),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusSmall),
                ),
                child: const Icon(Icons.send_rounded,
                    color: AppColors.textPrimary, size: 20),
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
