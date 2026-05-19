import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
class FeatureItem {
  const FeatureItem({required this.text, required this.included});

  final String text;
  final bool included;
}

class FeatureRow extends StatefulWidget {
  const FeatureRow({
    super.key,
    required this.item,
    required this.accentColor,
    required this.index,
  });

  final FeatureItem item;
  final Color accentColor;
  final int index;

  @override
  State<FeatureRow> createState() => _FeatureRowState();
}

class _FeatureRowState extends State<FeatureRow> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 60 + widget.index * 50), () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isIncluded = widget.item.included;
    final iconColor = isIncluded ? widget.accentColor : AppColors.textTertiary;
    final textColor = isIncluded
        ? AppColors.textSecondary
        : AppColors.textTertiary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _visible ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isIncluded ? Icons.check_circle_rounded : Icons.close_rounded,
              color: iconColor,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.item.text,
                style: AppTextStyles.bodySmall(color: textColor).copyWith(
                  decoration: isIncluded
                      ? TextDecoration.none
                      : TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
