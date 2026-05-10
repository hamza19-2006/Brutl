import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<ChatProvider>().pendingRequests;

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
        title: Text('Friend Requests', style: AppTextStyles.headingLarge()),
      ),
      body: requests.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline_rounded,
                      color: AppColors.textTertiary, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No pending requests',
                    style: AppTextStyles.bodyMedium(
                        color: AppColors.textTertiary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: requests.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (ctx, index) {
                final request = requests[index];
                return _RequestCard(request: request);
              },
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final FriendRequestModel request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundTertiary,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.backgroundQuaternary,
            backgroundImage: request.senderPhotoUrl.isNotEmpty
                ? CachedNetworkImageProvider(request.senderPhotoUrl)
                : null,
            child: request.senderPhotoUrl.isEmpty
                ? const Icon(Icons.person,
                    color: AppColors.textTertiary, size: 24)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.senderDisplayName.isNotEmpty
                      ? request.senderDisplayName
                      : request.senderUsername,
                  style: AppTextStyles.headingSmall(),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${request.senderUsername}',
                  style: AppTextStyles.labelSmall(
                      color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          // Accept
          _ActionButton(
            icon: Icons.check_rounded,
            color: AppColors.statusSuccess,
            onTap: () => context
                .read<ChatProvider>()
                .acceptFriendRequest(request.senderUid),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Decline
          _ActionButton(
            icon: Icons.close_rounded,
            color: AppColors.statusError,
            onTap: () => context
                .read<ChatProvider>()
                .declineFriendRequest(request.senderUid),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
