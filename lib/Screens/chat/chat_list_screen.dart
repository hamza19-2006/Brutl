import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../settings/main_settings_screen.dart';
import 'ai_chat_screen.dart';
import 'chat_room_screen.dart';
import 'friend_requests_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  /// Track UIDs whose friend request has already been sent in this session.
  final Set<String> _sentRequests = {};

  @override
  void initState() {
    super.initState();
    final chatProvider = context.read<ChatProvider>();
    chatProvider.listenToFriends();
    chatProvider.listenToFriendRequests();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool get _isSearchUiActive =>
      _searchController.text.trim().isNotEmpty || _searchFocusNode.hasFocus;

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await context.read<ChatProvider>().searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _sendRequest(String targetUid) async {
    setState(() => _sentRequests.add(targetUid));
    await context.read<ChatProvider>().sendFriendRequest(targetUid);
  }

  // ---------------------------------------------------------------------------
  // Long-press modal
  // ---------------------------------------------------------------------------

  void _showFriendContextMenu(FriendModel friend) {
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
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ContextMenuItem(
                  icon: Icons.edit_rounded,
                  label: 'Edit Name',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditNicknameDialog(friend);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _ContextMenuItem(
                  icon: Icons.person_remove_rounded,
                  label: 'Remove Friend',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRemoveFriendDialog(friend);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _ContextMenuItem(
                  icon: Icons.delete_sweep_rounded,
                  label: 'Delete Chat History',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showClearChatDialog(friend);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditNicknameDialog(FriendModel friend) {
    final controller = TextEditingController(text: friend.nickname);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text('Edit Name', style: AppTextStyles.headingMedium()),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nickname',
            hintStyle: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.backgroundQuaternary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
              borderSide: const BorderSide(color: AppColors.borderDefault),
            ),
          ),
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
              context.read<ChatProvider>().setLocalNickname(
                friend.uid,
                controller.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: Text(
              'Save',
              style: AppTextStyles.bodyMedium(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveFriendDialog(FriendModel friend) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text(
          'Remove Friend',
          style: AppTextStyles.headingMedium(color: AppColors.statusError),
        ),
        content: Text(
          'Are you sure you want to remove ${friend.resolvedName}?',
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
              context.read<ChatProvider>().removeFriend(friend.uid);
              Navigator.pop(ctx);
            },
            child: Text(
              'Remove',
              style: AppTextStyles.bodyMedium(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearChatDialog(FriendModel friend) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text(
          'Delete Chat History',
          style: AppTextStyles.headingMedium(color: AppColors.statusError),
        ),
        content: Text(
          'Clear all messages with ${friend.resolvedName}?',
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
              final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final chatId = buildChatId(myUid, friend.uid);
              context.read<ChatProvider>().clearChatHistory(chatId);
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

  // ---------------------------------------------------------------------------
  // Avatar pop-up
  // ---------------------------------------------------------------------------

  void _showAvatarPopup(FriendModel friend) {
    if (friend.photoUrl.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'avatar_${friend.uid}',
                child: Container(
                  width: MediaQuery.of(ctx).size.width * 0.5,
                  height: MediaQuery.of(ctx).size.width * 0.5,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderStrong, width: 3),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(friend.photoUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).size.height * 0.2,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final friendsList = chatProvider.friends;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return PopScope<void>(
      canPop: !_isSearchUiActive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _clearSearch();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundPrimary,
          elevation: 0,
          leading: myUid.isEmpty
              ? _BellIcon(
                  count: 0,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const FriendRequestsScreen(),
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(myUid)
                      .collection('friend_requests')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int pendingCount;
                    if (snapshot.hasError) {
                      debugPrint(
                        'Friend requests stream error in ChatListScreen: ${snapshot.error}',
                      );
                      pendingCount = chatProvider.pendingRequestCount;
                    } else if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      pendingCount = chatProvider.pendingRequestCount;
                    } else {
                      pendingCount = snapshot.data?.docs.length ?? 0;
                    }
                    return _BellIcon(
                      count: pendingCount,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const FriendRequestsScreen(),
                        ),
                      ),
                    );
                  },
                ),
          title: Text('Chat', style: AppTextStyles.headingLarge()),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(
                Icons.settings_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const MainSettingsScreen(),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textTertiary,
                  ),
                  suffixIcon: _isSearchUiActive
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : null,
                  hintText: 'Search by username...',
                  hintStyle: AppTextStyles.bodyMedium(
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundTertiary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusMedium,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.borderDefault,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusMedium,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.borderDefault,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusMedium,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.accentPrimary,
                    ),
                  ),
                ),
              ),
            ),

            // Search results overlay
            if (_searchController.text.trim().isNotEmpty)
              _SearchResultsList(
                results: _searchResults,
                isLoading: _isSearching,
                sentRequests: _sentRequests,
                existingFriendUids: friendsList.map((f) => f.uid).toSet(),
                onAdd: _sendRequest,
              ),

            // Chat list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                itemCount: 1 + friendsList.length, // AI + friends
                itemBuilder: (ctx, index) {
                  if (index == 0) return _AiChatTile();

                  final friend = friendsList[index - 1];
                  return _FriendChatTile(
                    friend: friend,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ChatRoomScreen(friend: friend),
                      ),
                    ),
                    onLongPress: () => _showFriendContextMenu(friend),
                    onAvatarTap: () => _showAvatarPopup(friend),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Bell icon with badge + shake animation
// =============================================================================

class _BellIcon extends StatelessWidget {
  const _BellIcon({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget bell = IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_rounded,
            color: AppColors.textPrimary,
            size: 26,
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.statusError,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall(color: AppColors.textPrimary),
                ),
              ),
            ),
        ],
      ),
    );

    if (count > 0) {
      bell = bell
          .animate(onPlay: (c) => c.repeat())
          .shake(duration: 600.ms, hz: 3, rotation: 0.06)
          .then(delay: 2000.ms);
    }

    return bell;
  }
}

// =============================================================================
// AI Chat tile (Index 0)
// =============================================================================

class _AiChatTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accentGlow,
          border: Border.all(color: AppColors.accentPrimary, width: 2),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        ),
        child: const Icon(
          Icons.smart_toy_rounded,
          color: AppColors.accentPrimary,
          size: 26,
        ),
      ),
      title: Text('AI Trainer', style: AppTextStyles.headingSmall()),
      subtitle: Text(
        'Ask me anything about fitness',
        style: AppTextStyles.bodySmall(color: AppColors.textTertiary),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const AiChatScreen()),
      ),
    );
  }
}

// =============================================================================
// Friend chat tile
// =============================================================================

class _FriendChatTile extends StatefulWidget {
  const _FriendChatTile({
    required this.friend,
    required this.onTap,
    required this.onLongPress,
    required this.onAvatarTap,
  });

  final FriendModel friend;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onAvatarTap;

  @override
  State<_FriendChatTile> createState() => _FriendChatTileState();
}

class _FriendChatTileState extends State<_FriendChatTile> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _chatStream;
  late final String _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (_myUid.isEmpty) {
      _chatStream =
          const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    } else {
      final chatId = buildChatId(_myUid, widget.friend.uid);
      _chatStream = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .snapshots();
    }
  }

  String _unreadLabel(int count) {
    if (count >= 4) return '4+ new messages';
    if (count == 1) return '1 new message';
    return '$count new messages';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _chatStream,
      builder: (context, snapshot) {
        final chatData = snapshot.data?.data() ?? const <String, dynamic>{};
        final unreadCount =
            (chatData['unreadCount_$_myUid'] as num?)?.toInt() ?? 0;
        final hasUnread = unreadCount > 0;

        final lastMessage = (chatData['lastMessage'] as String?)?.trim() ?? '';
        final subtitleText = lastMessage.isNotEmpty
            ? lastMessage
            : '@${widget.friend.username}';

        return InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Avatar (tappable separately)
                GestureDetector(
                  onTap: widget.onAvatarTap,
                  child: Hero(
                    tag: 'avatar_${widget.friend.uid}',
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.backgroundQuaternary,
                      backgroundImage: widget.friend.photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(widget.friend.photoUrl)
                          : null,
                      child: widget.friend.photoUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              color: AppColors.textTertiary,
                              size: 24,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.friend.resolvedName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headingSmall(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTextStyles.bodySmall(
                              color: hasUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ).copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusError,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusFull,
                      ),
                    ),
                    child: Text(
                      _unreadLabel(unreadCount),
                      style: AppTextStyles.labelSmall(
                        color: AppColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Search results list
// =============================================================================

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.results,
    required this.isLoading,
    required this.sentRequests,
    required this.existingFriendUids,
    required this.onAdd,
  });

  final List<Map<String, dynamic>> results;
  final bool isLoading;
  final Set<String> sentRequests;
  final Set<String> existingFriendUids;
  final Future<void> Function(String uid) onAdd;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accentPrimary),
        ),
      );
    }

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'No users found',
          style: AppTextStyles.bodySmall(color: AppColors.textTertiary),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundTertiary,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: results.length,
        separatorBuilder: (_, index) =>
            const Divider(height: 1, color: AppColors.borderSubtle),
        itemBuilder: (ctx, i) {
          final user = results[i];
          final uid = user['uid'] as String? ?? '';
          final displayName = user['display_name'] as String? ?? '';
          final username = user['username'] as String? ?? '';
          final photoUrl = user['photo_url'] as String? ?? '';
          final isFriend = existingFriendUids.contains(uid);
          final isSent = sentRequests.contains(uid);

          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.backgroundQuaternary,
              backgroundImage: photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: photoUrl.isEmpty
                  ? const Icon(
                      Icons.person,
                      color: AppColors.textTertiary,
                      size: 20,
                    )
                  : null,
            ),
            title: Text(displayName, style: AppTextStyles.headingSmall()),
            subtitle: Text(
              '@$username',
              style: AppTextStyles.labelSmall(color: AppColors.textTertiary),
            ),
            trailing: isFriend
                ? Text(
                    'Friends',
                    style: AppTextStyles.labelSmall(
                      color: AppColors.statusSuccess,
                    ),
                  )
                : isSent
                ? Text(
                    'Sent',
                    style: AppTextStyles.labelSmall(
                      color: AppColors.textTertiary,
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.person_add_rounded,
                      color: AppColors.accentPrimary,
                      size: 22,
                    ),
                    onPressed: () => onAdd(uid),
                  ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Context menu item
// =============================================================================

class _ContextMenuItem extends StatelessWidget {
  const _ContextMenuItem({
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
    final color = isDestructive ? AppColors.statusError : AppColors.textPrimary;
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
