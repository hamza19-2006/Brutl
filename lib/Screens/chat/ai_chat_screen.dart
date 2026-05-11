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
