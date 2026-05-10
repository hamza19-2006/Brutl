import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/ai_coach_provider.dart';

class AiCoachChatScreen extends StatefulWidget {
  const AiCoachChatScreen({
    super.key,
    this.initialDraft,
    this.initialAttachment,
  });

  final String? initialDraft;
  final AiCoachAttachment? initialAttachment;

  @override
  State<AiCoachChatScreen> createState() => _AiCoachChatScreenState();
}

class _AiCoachChatScreenState extends State<AiCoachChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AiCoachAttachment? _attachment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AiCoachProvider>().initialize();
      final initialDraft = widget.initialDraft?.trim();
      if (initialDraft != null && initialDraft.isNotEmpty) {
        _controller.text = initialDraft;
      }
      if (widget.initialAttachment != null) {
        setState(() => _attachment = widget.initialAttachment);
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<AiCoachProvider>();
    if (_scrollController.position.pixels < 140 &&
        provider.hasMore &&
        !provider.isLoadingMore &&
        !provider.isLoading) {
      provider.loadOlderMessages();
    }
  }

  Future<void> _send() async {
    final provider = context.read<AiCoachProvider>();
    final text = _controller.text.trim();
    final attachment = _attachment;
    if (text.isEmpty && attachment == null) return;

    _controller.clear();
    setState(() => _attachment = null);
    await provider.sendMessage(text, attachment: attachment);

    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _attach() async {
    final attachment = await showModalBottomSheet<AiCoachAttachment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundSecondary,
      builder: (_) => const _AttachmentSheet(),
    );
    if (!mounted || attachment == null) return;
    setState(() => _attachment = attachment);
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Elite AI Coach', style: AppTextStyles.headingMedium()),
      ),
      body: Consumer<AiCoachProvider>(
        builder: (context, provider, _) {
          final messages = provider.messages;
          return Column(
            children: [
              Expanded(
                child: provider.isLoading && messages.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentPrimary,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: messages.isEmpty
                            ? 1
                            : messages.length +
                                  (provider.isLoadingMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (messages.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 120),
                              child: Text(
                                'Ask me about workouts, nutrition, recovery, and progress.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyMedium(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            );
                          }
                          if (provider.isLoadingMore && i == 0) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: AppColors.textTertiary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final message =
                              messages[i - (provider.isLoadingMore ? 1 : 0)];
                          return _MessageBubble(message: message);
                        },
                      ),
              ),
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.statusError.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusSmall,
                      ),
                      border: Border.all(
                        color: AppColors.statusError.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      provider.error!,
                      style: AppTextStyles.bodySmall(
                        color: AppColors.statusError,
                      ),
                    ),
                  ),
                ),
              _Composer(
                controller: _controller,
                attachment: _attachment,
                isSending: provider.isSending,
                onAttach: _attach,
                onClearAttachment: () => setState(() => _attachment = null),
                onSend: _send,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.attachment,
    required this.isSending,
    required this.onAttach,
    required this.onClearAttachment,
    required this.onSend,
  });

  final TextEditingController controller;
  final AiCoachAttachment? attachment;
  final bool isSending;
  final VoidCallback onAttach;
  final VoidCallback onClearAttachment;
  final Future<void> Function() onSend;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachment != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusSmall,
                  ),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Row(
                  children: [
                    Icon(
                      _attachmentIcon(attachment!.type),
                      color: AppColors.accentPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        attachment!.type.toUpperCase(),
                        style: AppTextStyles.labelLarge(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onClearAttachment,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: isSending ? null : onAttach,
                  icon: const Icon(Icons.attach_file_rounded),
                  color: AppColors.textSecondary,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isSending,
                    maxLines: 5,
                    minLines: 1,
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: AppTextStyles.bodyMedium(
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.backgroundTertiary,
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
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: isSending ? null : onSend,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusSmall,
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSending
                          ? AppColors.textDisabled
                          : AppColors.accentPrimary,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusSmall,
                      ),
                    ),
                    child: isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AiCoachMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.accentPrimary
              : AppColors.backgroundTertiary,
          border: Border.all(
            color: isUser ? AppColors.accentPrimary : AppColors.borderDefault,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.attachmentType != null &&
                message.attachmentData != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _AttachmentCard(
                  type: message.attachmentType!,
                  data: message.attachmentData!,
                ),
              ),
            _MarkdownText(
              message.content,
              style: AppTextStyles.bodyMedium(
                color: isUser ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    if (type == 'image') {
      final imageUrl = data['url'] as String? ?? '';
      final caption = data['caption'] as String? ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  color: AppColors.backgroundSecondary,
                  alignment: Alignment.center,
                  child: Text(
                    'Image unavailable',
                    style: AppTextStyles.labelLarge(),
                  ),
                ),
              ),
            ),
          if (caption.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(caption, style: AppTextStyles.bodySmall()),
          ],
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type.toUpperCase(),
            style: AppTextStyles.labelLarge(color: AppColors.accentPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...data.entries.map(
            (entry) => Text(
              '${entry.key}: ${entry.value}',
              style: AppTextStyles.bodySmall(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentSheet extends StatefulWidget {
  const _AttachmentSheet();

  @override
  State<_AttachmentSheet> createState() => _AttachmentSheetState();
}

class _AttachmentSheetState extends State<_AttachmentSheet> {
  String _type = 'image';
  final TextEditingController _jsonController = TextEditingController(
    text: '{"url":"","caption":""}',
  );

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attach Data', style: AppTextStyles.headingMedium()),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            value: _type,
            items: const [
              DropdownMenuItem(value: 'image', child: Text('Image')),
              DropdownMenuItem(value: 'workout', child: Text('Workout')),
              DropdownMenuItem(value: 'meal', child: Text('Meal')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _type = value;
                if (value == 'image') {
                  _jsonController.text = '{"url":"","caption":""}';
                } else if (value == 'workout') {
                  _jsonController.text = '{"title":"","sets":"","reps":""}';
                } else {
                  _jsonController.text =
                      '{"name":"","calories":"","protein":"","carbs":"","fat":""}';
                }
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _jsonController,
            minLines: 4,
            maxLines: 8,
            style: AppTextStyles.bodySmall(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'JSON attachment payload',
              hintStyle: AppTextStyles.bodySmall(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.backgroundTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                try {
                  final decoded = jsonDecode(_jsonController.text.trim());
                  if (decoded is! Map) return;
                  Navigator.of(context).pop(
                    AiCoachAttachment(
                      type: _type,
                      data: Map<String, dynamic>.from(decoded as Map),
                    ),
                  );
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid JSON payload')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text('Attach'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownText extends StatelessWidget {
  const _MarkdownText(this.data, {required this.style});

  final String data;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map((line) {
            if (line.startsWith('# ')) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  line.substring(2),
                  style: AppTextStyles.headingSmall(
                    color: style.color ?? AppColors.textPrimary,
                  ),
                ),
              );
            }
            if (line.startsWith('- ')) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text('• ${line.substring(2)}', style: style),
              );
            }
            return SelectableText.rich(
              TextSpan(children: _inline(line, style)),
            );
          })
          .toList(growable: false),
    );
  }

  List<InlineSpan> _inline(String text, TextStyle baseStyle) {
    if (!text.contains('**')) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final spans = <InlineSpan>[];
    var current = text;
    while (current.contains('**')) {
      final start = current.indexOf('**');
      final end = current.indexOf('**', start + 2);
      if (end == -1) break;
      if (start > 0) {
        spans.add(
          TextSpan(text: current.substring(0, start), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: current.substring(start + 2, end),
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      );
      current = current.substring(end + 2);
    }
    if (current.isNotEmpty) {
      spans.add(TextSpan(text: current, style: baseStyle));
    }
    return spans;
  }
}

IconData _attachmentIcon(String type) {
  switch (type) {
    case 'image':
      return Icons.image_outlined;
    case 'workout':
      return Icons.fitness_center_rounded;
    case 'meal':
      return Icons.restaurant_menu_rounded;
    default:
      return Icons.attachment_rounded;
  }
}

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) => const AiCoachChatScreen();
}
