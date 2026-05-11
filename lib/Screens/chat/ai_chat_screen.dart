import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/ai_coach_provider.dart';
import 'share_meal_screen.dart';
import 'share_workout_screen.dart';

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
    final hasAttachment =
        message.attachmentType != null && message.attachmentData != null;
    final hasContent = message.content.trim().isNotEmpty;
    final maxWidth = MediaQuery.of(context).size.width * 0.84;

    final bubbleRadius = isUser
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (hasAttachment)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _AttachmentCard(
                type: message.attachmentType!,
                data: message.attachmentData!,
                isUser: isUser,
              ),
            ),
          if (hasAttachment && hasContent)
            const SizedBox(height: AppSpacing.xs),
          if (hasContent)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.accentPrimary
                    : const Color(0xFF171A1F),
                border: Border.all(
                  color: isUser
                      ? AppColors.accentPrimary
                      : AppColors.borderDefault,
                ),
                borderRadius: bubbleRadius,
              ),
              child: _MarkdownText(
                message.content,
                style: AppTextStyles.bodyMedium(
                  color: isUser
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.type,
    required this.data,
    required this.isUser,
  });

  final String type;
  final Map<String, dynamic> data;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'image':
        return _AiImageAttachment(data: data);
      case 'meal':
        return _AiMealAttachment(data: data, isUser: isUser);
      case 'workout':
        return _AiWorkoutAttachment(data: data, isUser: isUser);
      default:
        return _AiFallbackAttachment(type: type, data: data);
    }
  }
}

class _AiImageAttachment extends StatelessWidget {
  const _AiImageAttachment({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final imageUrl = data['url'] as String? ?? '';
    final caption = data['caption'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF14181D),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
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
      ),
    );
  }
}

class _AiMealAttachment extends StatelessWidget {
  const _AiMealAttachment({required this.data, required this.isUser});
  final Map<String, dynamic> data;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final mealName = data['name'] as String? ?? 'Meal';
    final calories = data['calories'] as num? ?? 0;
    final protein = data['protein'] as num? ?? 0;
    final carbs = data['carbs'] as num? ?? 0;
    final fats = (data['fat'] ?? data['fats']) as num? ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF14181D),
        border: Border.all(
          color: isUser ? AppColors.borderAccent : AppColors.borderSubtle,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_menu_rounded,
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
              _AiMacroPill(
                label: 'Protein',
                value: '${protein}g',
                color: AppColors.statusSuccess,
              ),
              _AiMacroPill(
                label: 'Carbs',
                value: '${carbs}g',
                color: AppColors.statusInfo,
              ),
              _AiMacroPill(
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

class _AiWorkoutAttachment extends StatelessWidget {
  const _AiWorkoutAttachment({required this.data, required this.isUser});
  final Map<String, dynamic> data;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final scope = data['shareScope'] as String? ?? 'day';
    final title =
        data['title'] as String? ?? data['name'] as String? ?? 'Workout';
    final exercises = (data['exercises'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final days = (data['days'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    final IconData headerIcon;
    final Widget body;
    switch (scope) {
      case 'week':
        headerIcon = Icons.calendar_month_rounded;
        body = _AiWorkoutWeekBody(days: days);
      case 'exercise':
        headerIcon = Icons.sports_gymnastics_rounded;
        final sets = exercises.isNotEmpty ? exercises[0]['sets'] : null;
        final reps = exercises.isNotEmpty ? exercises[0]['reps'] : null;
        body = _AiWorkoutExerciseBody(sets: sets, reps: reps);
      default:
        headerIcon = Icons.fitness_center_rounded;
        body = _AiWorkoutDayBody(exercises: exercises);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF151A20),
        border: Border.all(
          color: isUser ? AppColors.borderAccent : AppColors.borderDefault,
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
        ],
      ),
    );
  }
}

class _AiWorkoutWeekBody extends StatelessWidget {
  const _AiWorkoutWeekBody({required this.days});
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

class _AiWorkoutDayBody extends StatelessWidget {
  const _AiWorkoutDayBody({required this.exercises});
  final List<Map<String, dynamic>> exercises;

  @override
  Widget build(BuildContext context) {
    final preview = exercises.take(4).toList();
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
        if (exercises.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+ ${exercises.length - 4} more',
              style: AppTextStyles.labelSmall(color: AppColors.textTertiary),
            ),
          ),
      ],
    );
  }
}

class _AiWorkoutExerciseBody extends StatelessWidget {
  const _AiWorkoutExerciseBody({required this.sets, required this.reps});
  final dynamic sets;
  final dynamic reps;

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

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _AiMacroPill(
          label: 'Sets',
          value: sets?.toString() ?? '-',
          color: AppColors.accentPrimary,
        ),
        _AiMacroPill(
          label: 'Reps',
          value: _formatReps(reps),
          color: AppColors.statusInfo,
        ),
      ],
    );
  }
}

class _AiMacroPill extends StatelessWidget {
  const _AiMacroPill({
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

class _AiFallbackAttachment extends StatelessWidget {
  const _AiFallbackAttachment({required this.type, required this.data});
  final String type;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF14181D),
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
  final ImagePicker _imagePicker = ImagePicker();
  bool _isBusy = false;

  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusLarge),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.textPrimary,
                ),
                title: Text('Camera', style: AppTextStyles.bodyMedium()),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.textPrimary,
                ),
                title: Text('Gallery', style: AppTextStyles.bodyMedium()),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Uint8List _compressImage(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return imageBytes;

    const maxDimension = 1280;
    final resized = decoded.width >= decoded.height
        ? (decoded.width > maxDimension
              ? img.copyResize(decoded, width: maxDimension)
              : decoded)
        : (decoded.height > maxDimension
              ? img.copyResize(decoded, height: maxDimension)
              : decoded);

    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  Future<void> _attachImage() async {
    if (_isBusy) return;
    final source = await _pickImageSource();
    if (!mounted || source == null) return;

    setState(() => _isBusy = true);
    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (picked == null) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        throw StateError('You must be signed in to attach an image.');
      }

      final rawBytes = await picked.readAsBytes();
      final compressedBytes = _compressImage(rawBytes);
      final uuid = DateTime.now().microsecondsSinceEpoch.toString();
      final storagePath = 'ai_coach_images/$uid/$uuid.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      await storageRef.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      if (!mounted) return;
      Navigator.of(context).pop(
        AiCoachAttachment(
          type: 'image',
          data: <String, dynamic>{'url': downloadUrl},
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not attach image. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _attachWorkout() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final payload = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute<Map<String, dynamic>>(
          builder: (_) => const ShareWorkoutScreen(),
        ),
      );
      if (!mounted || payload == null) return;

      final exercisesRaw = payload['exercises'] as List<dynamic>? ?? const [];
      final exercises = exercisesRaw
          .whereType<Map>()
          .map(
            (exercise) => <String, dynamic>{
              'exerciseName': exercise['exerciseName'],
              'sets': exercise['sets'],
              'reps': exercise['reps'],
              'weight': exercise['weight'],
              if (exercise['day'] != null) 'day': exercise['day'],
            },
          )
          .toList(growable: false);

      final attachmentData = <String, dynamic>{
        'title': payload['title'] ?? 'Workout',
        'shareScope': payload['shareScope'],
        if (payload['weekNumber'] != null) 'weekNumber': payload['weekNumber'],
        if (payload['days'] != null) 'days': payload['days'],
        'exercises': exercises,
      };

      Navigator.of(context).pop(
        AiCoachAttachment(type: 'workout', data: attachmentData),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _attachMeal() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final payload = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute<Map<String, dynamic>>(
          builder: (_) => const ShareMealScreen(),
        ),
      );
      if (!mounted || payload == null) return;

      final attachmentData = <String, dynamic>{
        'name': payload['mealName'] ?? 'Meal',
        'calories': payload['calories'] ?? 0,
        'protein': payload['protein'] ?? 0,
        'carbs': payload['carbs'] ?? 0,
        'fat': payload['fats'] ?? 0,
      };

      Navigator.of(context).pop(
        AiCoachAttachment(type: 'meal', data: attachmentData),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
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
          Text('Attach', style: AppTextStyles.headingMedium()),
          const SizedBox(height: AppSpacing.md),
          _AttachmentSheetOption(
            icon: Icons.image_outlined,
            label: 'Image',
            onTap: _isBusy ? null : _attachImage,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AttachmentSheetOption(
            icon: Icons.fitness_center_rounded,
            label: 'Workout',
            onTap: _isBusy ? null : _attachWorkout,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AttachmentSheetOption(
            icon: Icons.restaurant_menu_rounded,
            label: 'Meal',
            onTap: _isBusy ? null : _attachMeal,
          ),
          if (_isBusy) ...[
            const SizedBox(height: AppSpacing.md),
            const SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(color: AppColors.accentPrimary),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentSheetOption extends StatelessWidget {
  const _AttachmentSheetOption({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentPrimary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium())),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight Markdown renderer for AI chat replies.
///
/// Supports:
/// * Multi-level headings: `#`, `##`, `###`, `####`.
/// * Inline bold via `**bold**`.
/// * Inline italic via `*italic*` (must be edge-flanked by non-space, so
///   `2 * 3` is preserved as-is).
/// * Inline code via `` `code` ``.
/// * Bullet lists via `- item` or `* item`.
/// * Ordered lists via `1. item`.
/// * Fenced code blocks via triple backticks.
class _MarkdownText extends StatelessWidget {
  const _MarkdownText(this.data, {required this.style});

  final String data;
  final TextStyle style;

  static final RegExp _headingRe = RegExp(r'^(#{1,4})\s+(.+?)\s*$');
  static final RegExp _bulletRe = RegExp(r'^\s*[-*]\s+(.+)$');
  static final RegExp _numberedRe = RegExp(r'^\s*(\d+)\.\s+(.+)$');

  // Inline tokenizer: bold (`**...**`), code (`` `...` ``), italic
  // (`*...*` with non-space edges). Non-greedy bodies so we never swallow
  // an entire paragraph if the model emits unbalanced asterisks.
  static final RegExp _inlineRe = RegExp(
    r'(?<bold>\*\*(?:[^*]|\*(?!\*))+?\*\*)'
    r'|(?<code>`[^`]+?`)'
    r'|(?<italic>\*(?:[^\s*][^*]*?[^\s*]|[^\s*])\*)',
  );

  @override
  Widget build(BuildContext context) {
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];

    var inCodeBlock = false;
    final codeBuffer = <String>[];

    for (final line in lines) {
      // Fenced code block toggle (```)
      if (line.trimRight().startsWith('```')) {
        if (inCodeBlock) {
          widgets.add(_CodeBlock(code: codeBuffer.join('\n')));
          codeBuffer.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        codeBuffer.add(line);
        continue;
      }

      // Headings (# / ## / ### / ####)
      final headingMatch = _headingRe.firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2)!;
        widgets.add(_buildHeading(level, text));
        continue;
      }

      // Bullet list
      final bulletMatch = _bulletRe.firstMatch(line);
      if (bulletMatch != null) {
        widgets.add(_buildListRow('•', bulletMatch.group(1)!));
        continue;
      }

      // Numbered list
      final numberedMatch = _numberedRe.firstMatch(line);
      if (numberedMatch != null) {
        widgets.add(
          _buildListRow('${numberedMatch.group(1)}.', numberedMatch.group(2)!),
        );
        continue;
      }

      // Empty line → small vertical gap (paragraph break).
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: AppSpacing.xs));
        continue;
      }

      // Regular paragraph
      widgets.add(
        SelectableText.rich(TextSpan(children: _inline(line, style))),
      );
    }

    // Flush an unclosed code block, just in case.
    if (inCodeBlock && codeBuffer.isNotEmpty) {
      widgets.add(_CodeBlock(code: codeBuffer.join('\n')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildHeading(int level, String text) {
    final color = style.color ?? AppColors.textPrimary;
    final TextStyle headingStyle;
    switch (level) {
      case 1:
        headingStyle = AppTextStyles.headingLarge(color: color);
      case 2:
        headingStyle = AppTextStyles.headingMedium(color: color);
      case 3:
        headingStyle = AppTextStyles.headingSmall(color: color);
      default:
        headingStyle = AppTextStyles.bodyLarge(
          color: color,
        ).copyWith(fontWeight: FontWeight.w700);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: SelectableText.rich(
        TextSpan(children: _inline(text, headingStyle)),
      ),
    );
  }

  Widget _buildListRow(String marker, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(marker, style: style.copyWith(height: 1.3)),
          ),
          Expanded(
            child: SelectableText.rich(
              TextSpan(children: _inline(content, style)),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _inline(String text, TextStyle baseStyle) {
    if (text.isEmpty) return const <InlineSpan>[];

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _inlineRe.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }

      final bold = match.namedGroup('bold');
      final code = match.namedGroup('code');
      final italic = match.namedGroup('italic');

      if (bold != null) {
        spans.add(
          TextSpan(
            text: bold.substring(2, bold.length - 2),
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (code != null) {
        spans.add(
          TextSpan(
            text: code.substring(1, code.length - 1),
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: AppColors.backgroundQuaternary,
            ),
          ),
        );
      } else if (italic != null) {
        spans.add(
          TextSpan(
            text: italic.substring(1, italic.length - 1),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }

    return spans;
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundQuaternary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: SelectableText(
        code,
        style: AppTextStyles.bodySmall(
          color: AppColors.textPrimary,
        ).copyWith(fontFamily: 'monospace', height: 1.4),
      ),
    );
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
