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
        content = Text(
          message.payload['text'] as String? ?? '',
          style: AppTextStyles.bodyMedium(
            color: isMe ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMe ? AppColors.accentPrimary : AppColors.backgroundTertiary,
          border: Border.all(
            color: isMe ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            content,
            const SizedBox(height: AppSpacing.xs),
            Text(
              timeStr,
              style: AppTextStyles.labelSmall(
                color: isMe
                    ? AppColors.textPrimary.withOpacity(0.7)
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

    final textColor =
        isMe ? AppColors.textPrimary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.restaurant_rounded,
                color: isMe
                    ? AppColors.textPrimary
                    : AppColors.accentPrimary,
                size: 18),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(mealName,
                  style: AppTextStyles.headingSmall(color: textColor)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: (isMe ? Colors.white : AppColors.backgroundQuaternary)
                .withOpacity(0.12),
            borderRadius:
                BorderRadius.circular(AppSpacing.borderRadiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MacroChip(label: 'Cal', value: '$calories', color: textColor),
              const SizedBox(width: AppSpacing.sm),
              _MacroChip(label: 'P', value: '${protein}g', color: textColor),
              const SizedBox(width: AppSpacing.sm),
              _MacroChip(label: 'C', value: '${carbs}g', color: textColor),
              const SizedBox(width: AppSpacing.sm),
              _MacroChip(label: 'F', value: '${fats}g', color: textColor),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.headingSmall(color: color)),
        Text(label, style: AppTextStyles.labelSmall(color: color)),
      ],
    );
  }
}

// =============================================================================
// Exercise share bubble
// =============================================================================

class _ExerciseShareBubble extends StatelessWidget {
  const _ExerciseShareBubble({required this.payload, required this.isMe});
  final Map<String, dynamic> payload;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name = payload['name'] as String? ?? 'Exercise';
    final exercises =
        (payload['exercises'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    final textColor =
        isMe ? AppColors.textPrimary : AppColors.textSecondary;
    final subtleColor =
        isMe ? AppColors.textPrimary.withOpacity(0.7) : AppColors.textTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.fitness_center_rounded,
                color: isMe
                    ? AppColors.textPrimary
                    : AppColors.accentPrimary,
                size: 18),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(name,
                  style: AppTextStyles.headingSmall(color: textColor)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final ex in exercises)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: (isMe
                        ? Colors.white
                        : AppColors.backgroundQuaternary)
                    .withOpacity(0.12),
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusSmall),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ex['exerciseName'] as String? ?? '',
                      style: AppTextStyles.bodySmall(color: textColor),
                    ),
                  ),
                  Text(
                    '${ex['sets'] ?? '-'}s × ${ex['reps'] ?? '-'}r',
                    style: AppTextStyles.labelSmall(color: subtleColor),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withOpacity(0.15)
                : AppColors.accentGlow,
            border: Border.all(
              color: isMe
                  ? Colors.white.withOpacity(0.3)
                  : AppColors.borderAccent,
            ),
            borderRadius:
                BorderRadius.circular(AppSpacing.borderRadiusSmall),
          ),
          child: Center(
            child: Text(
              'Save to My Plan',
              style: AppTextStyles.labelLarge(
                color: isMe
                    ? AppColors.textPrimary
                    : AppColors.accentPrimary,
              ),
            ),
          ),
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
