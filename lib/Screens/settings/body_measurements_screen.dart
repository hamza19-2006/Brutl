import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/body_measurement_model.dart';
import '../../models/user_model.dart';
import '../../providers/brutl_user_provider.dart';
import 'body_measurement_detail_screen.dart';
import 'widgets/settings_widgets.dart';

class BodyMeasurementsScreen extends StatelessWidget {
  const BodyMeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<BrutlUserProvider>().user;
    final measurements = _loadMeasurements(user);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Body Measurements'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsActionBoxWidget(
                children: measurements.asMap().entries.map((entry) {
                  final m = entry.value;
                  return SettingsTileWidget(
                    title: m.name,
                    trailingText: m.formattedDisplay,
                    onTap: () => _openDetail(context, m, measurements),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildAddButton(context, measurements),
            ],
          ),
        ),
      ),
    );
  }

  List<BodyMeasurement> _loadMeasurements(BrutlUser user) {
    final raw = user.bodyMeasurements;
    if (raw.isEmpty) {
      return BodyMeasurement.defaults();
    }
    return raw.map(BodyMeasurement.fromJson).toList();
  }

  void _openDetail(
    BuildContext context,
    BodyMeasurement measurement,
    List<BodyMeasurement> all,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BodyMeasurementDetailScreen(
          measurement: measurement,
          allMeasurements: all,
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, List<BodyMeasurement> current) {
    return ElevatedButton.icon(
      onPressed: () => _showAddDialog(context, current),
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        'Add Measurement',
        style: AppTextStyles.bodyLarge(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, List<BodyMeasurement> current) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: Text(
            'New Measurement',
            style: AppTextStyles.headingSmall(),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Neck, Calf, Forearm',
              hintStyle: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.backgroundPrimary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: AppTextStyles.bodyMedium()),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final newMeasurement = BodyMeasurement(
                    id: 'bm_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}',
                    name: name,
                    valueCm: 0.0,
                    displayUnit: 'cm',
                  );
                  final updated = [...current, newMeasurement];
                  _save(context, updated);
                }
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Add',
                style: AppTextStyles.bodyMedium(color: AppColors.accentPrimary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _save(BuildContext context, List<BodyMeasurement> measurements) {
    final jsonList = measurements.map((m) => m.toJson()).toList();
    context.read<BrutlUserProvider>().updateBodyMeasurements(jsonList);
  }
}
