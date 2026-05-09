import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_LocalMessage> _messages = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_LocalMessage(text: text, isUser: true));
      _messages.add(_LocalMessage(
        text: 'AI responses coming soon. Stay tuned!',
        isUser: false,
      ));
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accentGlow,
                border: Border.all(color: AppColors.accentPrimary, width: 1.5),
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusSmall),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: AppColors.accentPrimary, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('AI Trainer', style: AppTextStyles.headingMedium()),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.smart_toy_rounded,
                            color: AppColors.textTertiary, size: 56),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Ask me about workouts, nutrition, or anything fitness.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium(
                              color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      return Align(
                        alignment: msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(
                              bottom: AppSpacing.sm),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(ctx).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: msg.isUser
                                ? AppColors.accentPrimary
                                : AppColors.backgroundTertiary,
                            border: Border.all(
                              color: msg.isUser
                                  ? AppColors.accentPrimary
                                  : AppColors.borderDefault,
                            ),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.borderRadiusSmall),
                          ),
                          child: Text(
                            msg.text,
                            style: AppTextStyles.bodyMedium(
                              color: msg.isUser
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Input area
          Container(
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
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTextStyles.bodyMedium(
                          color: AppColors.textPrimary),
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
                          borderSide: const BorderSide(
                              color: AppColors.borderDefault),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.borderRadiusSmall),
                          borderSide: const BorderSide(
                              color: AppColors.borderDefault),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.borderRadiusSmall),
                          borderSide: const BorderSide(
                              color: AppColors.accentPrimary),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  InkWell(
                    onTap: _send,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.borderRadiusSmall),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary,
                        borderRadius: BorderRadius.circular(
                            AppSpacing.borderRadiusSmall),
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalMessage {
  const _LocalMessage({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}
