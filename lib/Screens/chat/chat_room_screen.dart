import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import 'share_meal_screen.dart';
import 'share_pr_screen.dart';
import 'share_streak_screen.dart';
import 'share_workout_screen.dart';
import 'start_challenge_screen.dart';

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

  /// Cached so dispose() can reach the provider after the element is
  /// deactivated (calling context.read inside dispose is unsafe).
  ChatProvider? _chatProviderRef;

  /// Message currently being replied to (null when not replying).
  MessageModel? _replyTo;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _chatId = buildChatId(_myUid, widget.friend.uid);
    unawaited(context.read<ChatProvider>().markChatAsRead(_chatId));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProviderRef = context.read<ChatProvider>();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    final providerRef = _chatProviderRef;
    if (providerRef != null) {
      unawaited(providerRef.setTypingStatus(_chatId, false));
    }
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
    final reply = _replyTo;
    context
        .read<ChatProvider>()
        .sendTextMessage(_chatId, text, replyTo: reply);
    _controller.clear();
    if (_replyTo != null) {
      setState(() => _replyTo = null);
    }
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
              const SizedBox(height: AppSpacing.md),
              _AttachOption(
                icon: Icons.emoji_events_rounded,
                label: 'Share PR',
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToPRShare();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _AttachOption(
                icon: Icons.local_fire_department_rounded,
                label: 'Share Streak',
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToStreakShare();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _AttachOption(
                icon: Icons.bolt_rounded,
                label: 'Start Challenge',
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToChallenge();
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

  Future<void> _navigateToPRShare() async {
    final payload = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => const SharePRScreen(),
      ),
    );
    if (payload != null && mounted) {
      await context.read<ChatProvider>().sendPRMessage(
            _chatId,
            exerciseName: payload['exerciseName'] as String,
            weight: (payload['weight'] as num).toDouble(),
            unit: payload['unit'] as String,
            reps: payload['reps'] as int,
            previousBest: (payload['previousBest'] as num?)?.toDouble(),
          );
      if (mounted) _scrollToBottom();
    }
  }

  Future<void> _navigateToStreakShare() async {
    final payload = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => const ShareStreakScreen(),
      ),
    );
    if (payload != null && mounted) {
      await context.read<ChatProvider>().sendStreakMessage(
            _chatId,
            streakDays: payload['streakDays'] as int,
            streakType: payload['streakType'] as String,
            note: payload['note'] as String?,
          );
      if (mounted) _scrollToBottom();
    }
  }

  Future<void> _navigateToChallenge() async {
    final payload = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => StartChallengeScreen(
          friendName: widget.friend.resolvedName,
        ),
      ),
    );
    if (payload != null && mounted) {
      await context.read<ChatProvider>().startChallenge(
            _chatId,
            widget.friend.uid,
            title: payload['title'] as String,
            type: payload['type'] as String,
            durationDays: payload['durationDays'] as int,
            targetValue: payload['targetValue'] as int,
          );
      if (mounted) _scrollToBottom();
    }
  }

  // ---------------------------------------------------------------------
  // Message long-press actions
  // ---------------------------------------------------------------------

  void _showMessageActions(MessageModel message) {
    if (message.isDeleted) return;
    final isMe = message.senderId == _myUid;
    final isText = message.type == 'text';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusLarge),
        ),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReactionPickerRow(
                  onSelect: (emoji) {
                    Navigator.pop(sheetCtx);
                    context
                        .read<ChatProvider>()
                        .toggleReaction(_chatId, message.id, emoji);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _MenuActionTile(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    setState(() => _replyTo = message);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                if (isText) ...[
                  _MenuActionTile(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      final text = message.payload['text'] as String? ?? '';
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                _MenuActionTile(
                  icon: Icons.info_outline_rounded,
                  label: 'Details',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showMessageDetailsSheet(message);
                  },
                ),
                if (isMe) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _MenuActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _confirmDeleteMessage(message);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessageDetailsSheet(MessageModel message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusLarge),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Details',
                  style: AppTextStyles.headingMedium(),
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: 'Sent',
                  value: DateFormat('MMM d, h:mm a').format(message.timestamp),
                ),
                if (message.readAt != null)
                  _DetailRow(
                    label: 'Seen',
                    value:
                        DateFormat('MMM d, h:mm a').format(message.readAt!),
                  )
                else
                  _DetailRow(
                    label: 'Status',
                    value: _statusLabel(message.status),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'read':
        return 'Read';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Sent';
    }
  }

  void _confirmDeleteMessage(MessageModel message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text(
          'Delete Message',
          style: AppTextStyles.headingMedium(color: AppColors.statusError),
        ),
        content: Text(
          'This message will be deleted for everyone.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<ChatProvider>().deleteMessage(_chatId, message);
              Navigator.pop(ctx);
            },
            child: Text(
              'Delete',
              style: AppTextStyles.bodyMedium(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: _buildAppBar(chatProvider),
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
                    final pendingIds = <String>{};
                    final optimistic = <MessageModel>[];
                    for (final m in chatProvider.optimisticMessages) {
                      if (!serverIds.contains(m.id)) {
                        optimistic.add(m);
                        pendingIds.add(m.id);
                      }
                    }
                    final allMessages = <MessageModel>[
                      ...serverMessages,
                      ...optimistic,
                    ];

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

                    // Interleave date separators between messages.
                    final items = <_RoomItem>[];
                    DateTime? lastDay;
                    for (final msg in allMessages) {
                      final day = DateTime(
                        msg.timestamp.year,
                        msg.timestamp.month,
                        msg.timestamp.day,
                      );
                      if (lastDay == null || day != lastDay) {
                        items.add(_RoomItem.separator(day));
                        lastDay = day;
                      }
                      items.add(_RoomItem.message(msg));
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
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        if (item.isSeparator) {
                          return _DateSeparator(day: item.day!);
                        }
                        final msg = item.message!;
                        final isMe = msg.senderId == _myUid;
                        return _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          myUid: _myUid,
                          chatId: _chatId,
                          friendUid: widget.friend.uid,
                          friendName: widget.friend.resolvedName,
                          isPending: pendingIds.contains(msg.id),
                          onLongPress: () => _showMessageActions(msg),
                          onReactionTap: (emoji) => chatProvider
                              .toggleReaction(_chatId, msg.id, emoji),
                        );
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
              if (_replyTo != null)
                _ReplyComposerPreview(
                  replyTo: _replyTo!,
                  isMine: _replyTo!.senderId == _myUid,
                  onClose: () => setState(() => _replyTo = null),
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

  PreferredSizeWidget _buildAppBar(ChatProvider chatProvider) {
    return AppBar(
      backgroundColor: AppColors.backgroundPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Hero(
            tag: 'avatar_${widget.friend.uid}',
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.backgroundQuaternary,
              backgroundImage: widget.friend.photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(widget.friend.photoUrl)
                  : null,
              child: widget.friend.photoUrl.isEmpty
                  ? const Icon(
                      Icons.person,
                      color: AppColors.textTertiary,
                      size: 18,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friend.resolvedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingSmall().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '@${widget.friend.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.labelSmall(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
      centerTitle: false,
    );
  }
}

/// Internal interleaved item for the message list (date separator vs message).
class _RoomItem {
  _RoomItem.separator(this.day)
      : message = null,
        isSeparator = true;
  _RoomItem.message(MessageModel m)
      : day = null,
        message = m,
        isSeparator = false;
  final bool isSeparator;
  final DateTime? day;
  final MessageModel? message;
}

// =============================================================================
// Message bubble
// =============================================================================

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.myUid,
    required this.chatId,
    required this.friendUid,
    required this.friendName,
    required this.isPending,
    required this.onLongPress,
    required this.onReactionTap,
  });

  final MessageModel message;
  final bool isMe;
  final String myUid;
  final String chatId;
  final String friendUid;
  final String friendName;
  final bool isPending;
  final VoidCallback onLongPress;
  final ValueChanged<String> onReactionTap;

  @override
  Widget build(BuildContext context) {
    final isTextMessage = message.type == 'text';
    final isDeleted = message.isDeleted;

    Widget content;
    if (isDeleted) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block_rounded,
            size: 14,
            color: isMe
                ? AppColors.textPrimary.withValues(alpha: 0.7)
                : AppColors.textTertiary,
          ),
          const SizedBox(width: 6),
          Text(
            'This message was deleted',
            style: AppTextStyles.bodyMedium(
              color: isMe
                  ? AppColors.textPrimary.withValues(alpha: 0.7)
                  : AppColors.textTertiary,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      );
    } else {
      switch (message.type) {
        case 'meal_share':
          content = _MealShareBubble(payload: message.payload, isMe: isMe);
          break;
        case 'exercise_share':
          content =
              _ExerciseShareBubble(payload: message.payload, isMe: isMe);
          break;
        case 'pr_share':
          content = _PRShareBubble(payload: message.payload, isMe: isMe);
          break;
        case 'streak_share':
          content =
              _StreakShareBubble(payload: message.payload, isMe: isMe);
          break;
        case 'challenge':
          content = _ChallengeBubble(
            payload: message.payload,
            isMe: isMe,
            chatId: chatId,
            myUid: myUid,
            friendUid: friendUid,
            friendName: friendName,
          );
          break;
        default:
          content = Text(
            message.payload['text'] as String? ?? '',
            style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
          );
      }
    }

    final useSolidBubble = isTextMessage || isDeleted;
    final bubbleColor = isDeleted
        ? (isMe ? AppColors.accentPrimary.withValues(alpha: 0.55) : const Color(0xFF171A1F))
        : (isMe ? AppColors.accentPrimary : const Color(0xFF171A1F));
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

    final showReply = message.isReply &&
        !isDeleted &&
        (message.replyToPreview ?? '').isNotEmpty;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.selectionClick();
          onLongPress();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: useSolidBubble
                    ? const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        6,
                      )
                    : null,
                decoration: useSolidBubble
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
                child: useSolidBubble
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showReply) ...[
                            _BubbleReplyChip(
                              preview: message.replyToPreview!,
                              isMine: message.replyToSenderId == myUid,
                              onMyBubble: isMe,
                            ),
                            const SizedBox(height: 6),
                          ],
                          content,
                          const SizedBox(height: 4),
                          _BubbleMeta(
                            time: message.timestamp,
                            isMe: isMe,
                            isPending: isPending,
                            status: message.status,
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showReply) ...[
                              _BubbleReplyChip(
                                preview: message.replyToPreview!,
                                isMine: message.replyToSenderId == myUid,
                                onMyBubble: isMe,
                              ),
                              const SizedBox(height: 6),
                            ],
                            content,
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 4),
                              child: Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: _BubbleMeta(
                                  time: message.timestamp,
                                  isMe: isMe,
                                  isPending: isPending,
                                  status: message.status,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (!isDeleted && message.hasReactions)
                _ReactionChips(
                  reactions: message.reactions,
                  myUid: myUid,
                  isMe: isMe,
                  onTap: onReactionTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the time and (for own messages) status ticks at the
/// bottom-right of the bubble.
class _BubbleMeta extends StatelessWidget {
  const _BubbleMeta({
    required this.time,
    required this.isMe,
    required this.isPending,
    required this.status,
  });

  final DateTime time;
  final bool isMe;
  final bool isPending;
  final String status;

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('h:mm a').format(time);
    final timeStyle = AppTextStyles.labelSmall(
      color: isMe
          ? AppColors.textPrimary.withValues(alpha: 0.85)
          : AppColors.textTertiary,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Text(timeText, style: timeStyle),
        if (isMe) ...[
          const SizedBox(width: 4),
          _StatusTicks(status: status, isPending: isPending),
        ],
      ],
    );
  }
}

class _StatusTicks extends StatelessWidget {
  const _StatusTicks({required this.status, required this.isPending});
  final String status;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    if (isPending) {
      return Icon(
        Icons.access_time_rounded,
        size: 13,
        color: AppColors.textPrimary.withValues(alpha: 0.7),
      );
    }
    if (status == 'read') {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: Color(0xFF60A5FA),
      );
    }
    if (status == 'delivered') {
      return Icon(
        Icons.done_all_rounded,
        size: 14,
        color: AppColors.textPrimary.withValues(alpha: 0.7),
      );
    }
    return Icon(
      Icons.done_rounded,
      size: 14,
      color: AppColors.textPrimary.withValues(alpha: 0.7),
    );
  }
}

class _BubbleReplyChip extends StatelessWidget {
  const _BubbleReplyChip({
    required this.preview,
    required this.isMine,
    required this.onMyBubble,
  });
  final String preview;
  final bool isMine;
  final bool onMyBubble;

  @override
  Widget build(BuildContext context) {
    final accent =
        onMyBubble ? AppColors.textPrimary : AppColors.accentPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: (onMyBubble
                ? AppColors.textPrimary
                : AppColors.accentPrimary)
            .withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMine ? 'You' : 'Reply',
            style: AppTextStyles.labelSmall(color: accent).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall(
              color: onMyBubble
                  ? AppColors.textPrimary.withValues(alpha: 0.85)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionChips extends StatelessWidget {
  const _ReactionChips({
    required this.reactions,
    required this.myUid,
    required this.isMe,
    required this.onTap,
  });

  final Map<String, List<String>> reactions;
  final String myUid;
  final bool isMe;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries.where((e) => e.value.isNotEmpty).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
      child: Wrap(
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final entry in entries)
            InkWell(
              onTap: () => onTap(entry.key),
              borderRadius:
                  BorderRadius.circular(AppSpacing.borderRadiusFull),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: entry.value.contains(myUid)
                      ? AppColors.accentSoft
                      : AppColors.backgroundTertiary,
                  border: Border.all(
                    color: entry.value.contains(myUid)
                        ? AppColors.accentPrimary
                        : AppColors.borderSubtle,
                  ),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 13)),
                    if (entry.value.length > 1) ...[
                      const SizedBox(width: 3),
                      Text(
                        '${entry.value.length}',
                        style: AppTextStyles.labelSmall(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
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
// PR share bubble (with celebration animation)
// =============================================================================

class _PRShareBubble extends StatefulWidget {
  const _PRShareBubble({required this.payload, required this.isMe});
  final Map<String, dynamic> payload;
  final bool isMe;

  @override
  State<_PRShareBubble> createState() => _PRShareBubbleState();
}

class _PRShareBubbleState extends State<_PRShareBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatWeight(double w) {
    if (w == w.roundToDouble()) return w.toStringAsFixed(0);
    return w.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final exercise =
        widget.payload['exerciseName'] as String? ?? 'Personal Record';
    final weight = (widget.payload['weight'] as num?)?.toDouble() ?? 0;
    final unit = widget.payload['unit'] as String? ?? 'kg';
    final reps = (widget.payload['reps'] as num?)?.toInt() ?? 1;
    final previousBest = (widget.payload['previousBest'] as num?)?.toDouble();
    final delta = (previousBest != null && previousBest > 0)
        ? (weight - previousBest)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1206), Color(0xFF14181D)],
        ),
        border: Border.all(
          color: widget.isMe
              ? AppColors.borderAccent
              : AppColors.borderDefault,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFB42A), Color(0xFFFF7A00)],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.borderRadiusSmall),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEW PR',
                      style: AppTextStyles.labelSmall(
                        color: const Color(0xFFFFB42A),
                      ).copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      exercise,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingSmall(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ScaleTransition(
            scale: _scale,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatWeight(weight),
                  style: AppTextStyles.headingLarge(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: AppTextStyles.headingSmall(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundQuaternary,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusFull,
                      ),
                    ),
                    child: Text(
                      '× $reps',
                      style: AppTextStyles.labelLarge(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (delta != null && delta > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: AppColors.statusSuccess,
                ),
                const SizedBox(width: 4),
                Text(
                  '+${_formatWeight(delta)} $unit from previous best',
                  style: AppTextStyles.labelSmall(
                    color: AppColors.statusSuccess,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Streak share bubble
// =============================================================================

class _StreakShareBubble extends StatelessWidget {
  const _StreakShareBubble({required this.payload, required this.isMe});
  final Map<String, dynamic> payload;
  final bool isMe;

  String _typeLabel(String t) {
    switch (t) {
      case 'workout':
        return 'Workout';
      case 'calories':
        return 'Calorie';
      default:
        return '';
    }
  }

  String? _milestoneLabel(int days) {
    if (days >= 365) return 'LEGENDARY · 365+ DAYS';
    if (days >= 100) return 'CENTURY · 100+ DAYS';
    if (days >= 60) return 'ELITE · 60+ DAYS';
    if (days >= 30) return 'MONTHLY MILESTONE';
    if (days >= 14) return 'TWO WEEK MARK';
    if (days >= 7) return 'ONE WEEK MARK';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final days = (payload['streakDays'] as num?)?.toInt() ?? 0;
    final type = payload['streakType'] as String? ?? 'general';
    final note = (payload['note'] as String? ?? '').trim();
    final typeLabel = _typeLabel(type);
    final milestone = _milestoneLabel(days);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF200D04), Color(0xFF14181D)],
        ),
        border: Border.all(
          color:
              isMe ? AppColors.borderAccent : AppColors.borderDefault,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFF7A00), Color(0xFFFF3D00)],
                  ),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusSmall),
                ),
                child: const Text('🔥', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: AppTextStyles.headingMedium(
                          color: AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w800, fontSize: 22),
                        children: [
                          TextSpan(
                            text: '$days',
                            style: AppTextStyles.headingLarge(
                              color: AppColors.accentPrimary,
                            ).copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: 'day${days == 1 ? '' : 's'}',
                            style: AppTextStyles.headingSmall(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      typeLabel.isEmpty
                          ? 'streak going strong'
                          : '$typeLabel streak going strong',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (milestone != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusFull),
                border: Border.all(color: AppColors.accentPrimary),
              ),
              child: Text(
                milestone,
                style: AppTextStyles.labelSmall(
                  color: AppColors.accentPrimary,
                ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '"$note"',
              style: AppTextStyles.bodySmall(color: AppColors.textSecondary)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Challenge bubble (live progress + update dialog)
// =============================================================================

class _ChallengeBubble extends StatelessWidget {
  const _ChallengeBubble({
    required this.payload,
    required this.isMe,
    required this.chatId,
    required this.myUid,
    required this.friendUid,
    required this.friendName,
  });

  final Map<String, dynamic> payload;
  final bool isMe;
  final String chatId;
  final String myUid;
  final String friendUid;
  final String friendName;

  IconData _typeIcon(String type) {
    switch (type) {
      case 'workout':
        return Icons.fitness_center_rounded;
      case 'calories':
        return Icons.local_fire_department_rounded;
      case 'steps':
        return Icons.directions_walk_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  String _unitLabel(String type) {
    switch (type) {
      case 'workout':
        return 'workouts';
      case 'calories':
        return 'days';
      case 'steps':
        return 'steps';
      default:
        return 'days';
    }
  }

  void _openProgressDialog(
    BuildContext context, {
    required int current,
    required int target,
    required String type,
    required String challengeId,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final unit = _unitLabel(type);
        // For step-style challenges step values are bigger.
        final stepCandidates = type == 'steps'
            ? const <int>[500, 1000, 2500, 5000]
            : const <int>[1, 3, 5];
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: Text(
            'Update Progress',
            style: AppTextStyles.headingMedium(),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You: $current / $target $unit',
                style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final step in stepCandidates)
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        context
                            .read<ChatProvider>()
                            .incrementChallengeProgress(
                              chatId,
                              challengeId,
                              step,
                            );
                      },
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusSmall,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          border: Border.all(color: AppColors.accentPrimary),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.borderRadiusSmall,
                          ),
                        ),
                        child: Text(
                          '+$step',
                          style: AppTextStyles.labelLarge(
                            color: AppColors.accentPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Close',
                style: AppTextStyles.bodyMedium(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final challengeId = payload['challengeId'] as String? ?? '';
    final title = payload['title'] as String? ?? 'Challenge';
    final type = payload['type'] as String? ?? 'general';
    final fallbackTarget = (payload['targetValue'] as num?)?.toInt() ?? 0;

    if (challengeId.isEmpty) {
      // Defensive: malformed payload — render basic info card.
      return _ChallengeStaticCard(
        title: title,
        type: type,
        target: fallbackTarget,
        isMe: isMe,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: context.read<ChatProvider>().challengeStream(chatId, challengeId),
      builder: (context, snap) {
        final data = snap.data?.data();
        final target =
            (data?['targetValue'] as num?)?.toInt() ?? fallbackTarget;
        final status = (data?['status'] as String?) ?? 'active';
        final endTs = data?['endDate'];
        DateTime? endDate;
        if (endTs is Timestamp) endDate = endTs.toDate();

        final progress = (data?['progress'] as Map<dynamic, dynamic>?) ??
            const <dynamic, dynamic>{};
        final myValue = ((progress[myUid] as Map?)?['currentValue'] as num?)
                ?.toInt() ??
            0;
        final theirValue =
            ((progress[friendUid] as Map?)?['currentValue'] as num?)
                    ?.toInt() ??
                0;

        final daysLeft = endDate == null
            ? null
            : endDate.difference(DateTime.now()).inDays;
        final isCompleted = status == 'completed';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF14181D),
            border: Border.all(
              color: isCompleted
                  ? AppColors.statusSuccess
                  : (isMe
                      ? AppColors.borderAccent
                      : AppColors.borderDefault),
            ),
            borderRadius:
                BorderRadius.circular(AppSpacing.borderRadiusMedium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      border: Border.all(color: AppColors.accentPrimary),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusSmall,
                      ),
                    ),
                    child: Icon(
                      _typeIcon(type),
                      color: AppColors.accentPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CHALLENGE',
                          style: AppTextStyles.labelSmall(
                            color: AppColors.accentPrimary,
                          ).copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headingSmall(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusSuccess
                            .withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.statusSuccess),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadiusFull,
                        ),
                      ),
                      child: Text(
                        'COMPLETE',
                        style: AppTextStyles.labelSmall(
                          color: AppColors.statusSuccess,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ChallengeProgressRow(
                label: 'You',
                current: myValue,
                target: target,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ChallengeProgressRow(
                label: friendName.isEmpty ? 'Friend' : friendName,
                current: theirValue,
                target: target,
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    daysLeft == null
                        ? '—'
                        : daysLeft <= 0
                            ? 'Ended'
                            : '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                    style: AppTextStyles.labelSmall(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  if (!isCompleted && (daysLeft == null || daysLeft > 0))
                    InkWell(
                      onTap: () => _openProgressDialog(
                        context,
                        current: myValue,
                        target: target,
                        type: type,
                        challengeId: challengeId,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusSmall,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.borderRadiusSmall,
                          ),
                        ),
                        child: Text(
                          'Update Progress',
                          style: AppTextStyles.labelLarge(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChallengeStaticCard extends StatelessWidget {
  const _ChallengeStaticCard({
    required this.title,
    required this.type,
    required this.target,
    required this.isMe,
  });

  final String title;
  final String type;
  final int target;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF14181D),
        border: Border.all(
          color: isMe ? AppColors.borderAccent : AppColors.borderDefault,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHALLENGE',
            style: AppTextStyles.labelSmall(color: AppColors.accentPrimary)
                .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.headingSmall(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Target: $target',
            style: AppTextStyles.labelSmall(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ChallengeProgressRow extends StatelessWidget {
  const _ChallengeProgressRow({
    required this.label,
    required this.current,
    required this.target,
  });

  final String label;
  final int current;
  final int target;

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    final isComplete = target > 0 && current >= target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '$current / $target',
              style: AppTextStyles.labelSmall(
                color: isComplete
                    ? AppColors.statusSuccess
                    : AppColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.backgroundQuaternary,
            valueColor: AlwaysStoppedAnimation<Color>(
              isComplete
                  ? AppColors.statusSuccess
                  : AppColors.accentPrimary,
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

// =============================================================================
// Date separator
// =============================================================================

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.day});
  final DateTime day;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return DateFormat('EEEE').format(day);
    if (day.year == now.year) return DateFormat('MMM d').format(day);
    return DateFormat('MMM d, yyyy').format(day);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundTertiary,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
        ),
        child: Text(
          _label(),
          style: AppTextStyles.labelSmall(color: AppColors.textTertiary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// =============================================================================
// Reply composer preview (shown above input bar while replying)
// =============================================================================

class _ReplyComposerPreview extends StatelessWidget {
  const _ReplyComposerPreview({
    required this.replyTo,
    required this.isMine,
    required this.onClose,
  });

  final MessageModel replyTo;
  final bool isMine;
  final VoidCallback onClose;

  String _previewText() {
    if (replyTo.isDeleted) return 'Message deleted';
    switch (replyTo.type) {
      case 'meal_share':
        return '🍽 Meal: ${replyTo.payload['mealName'] ?? ''}';
      case 'exercise_share':
        return '💪 Workout: ${replyTo.payload['title'] ?? replyTo.payload['name'] ?? ''}';
      default:
        return (replyTo.payload['text'] as String? ?? '').trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMine ? 'Replying to yourself' : 'Replying',
                  style: AppTextStyles.labelSmall(
                    color: AppColors.accentPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _previewText(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textTertiary,
              size: 18,
            ),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Reaction picker row (used inside long-press menu)
// =============================================================================

class _ReactionPickerRow extends StatelessWidget {
  const _ReactionPickerRow({required this.onSelect});
  final ValueChanged<String> onSelect;

  static const List<String> _emojis = <String>[
    '❤️',
    '🔥',
    '💪',
    '👏',
    '😂',
    '😮',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundTertiary,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final emoji in _emojis)
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onSelect(emoji);
              },
              borderRadius:
                  BorderRadius.circular(AppSpacing.borderRadiusFull),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Generic menu action tile (used in long-press sheet)
// =============================================================================

class _MenuActionTile extends StatelessWidget {
  const _MenuActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? AppColors.statusError : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundTertiary,
          border: Border.all(
            color: isDestructive
                ? AppColors.statusError.withValues(alpha: 0.3)
                : AppColors.borderDefault,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: AppTextStyles.headingSmall(color: color)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Key/value detail row (used in message-details sheet)
// =============================================================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.labelSmall(color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
