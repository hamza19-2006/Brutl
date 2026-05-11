import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_models.dart';
import 'widgets/settings_widgets.dart';

class BlockedFriendsScreen extends StatefulWidget {
  const BlockedFriendsScreen({super.key});

  @override
  State<BlockedFriendsScreen> createState() => _BlockedFriendsScreenState();
}

class _BlockedFriendsScreenState extends State<BlockedFriendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().listenToFriends();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Blocked Friends'),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final blocked = chatProvider.blockedUsers;

          if (blocked.isEmpty) {
            return Center(
              child: Text(
                'No blocked friends.',
                style: AppTextStyles.bodyLarge(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: blocked.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.sm + 2),
            itemBuilder: (context, index) {
              final friend = blocked[index];
              return _BlockedFriendTile(friend: friend);
            },
          );
        },
      ),
    );
  }
}

class _BlockedFriendTile extends StatelessWidget {
  const _BlockedFriendTile({required this.friend});

  final FriendModel friend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.backgroundTertiary,
          backgroundImage: friend.photoUrl.trim().isNotEmpty
              ? NetworkImage(friend.photoUrl)
              : null,
          child: friend.photoUrl.trim().isEmpty
              ? Text(
                  friend.resolvedName.isNotEmpty
                      ? friend.resolvedName[0].toUpperCase()
                      : '?',
                  style: AppTextStyles.headingSmall(
                    color: AppColors.textPrimary,
                  ),
                )
              : null,
        ),
        title: Text(
          friend.resolvedName,
          style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          friend.username.trim().isNotEmpty
              ? '@${friend.username}'
              : friend.uid,
          style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: TextButton(
          onPressed: () async {
            await context.read<ChatProvider>().setBlockedFriend(
              friend.uid,
              false,
            );
          },
          child: Text(
            'Unblock',
            style: AppTextStyles.headingSmall(color: AppColors.accentPrimary),
          ),
        ),
      ),
    );
  }
}
