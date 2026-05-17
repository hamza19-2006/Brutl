import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/body_measurement_model.dart';
import '../../providers/brutl_user_provider.dart';

class BodyMeasurementDetailScreen extends StatefulWidget {
  const BodyMeasurementDetailScreen({
    super.key,
    required this.measurement,
    required this.allMeasurements,
  });

  final BodyMeasurement measurement;
  final List<BodyMeasurement> allMeasurements;

  @override
  State<BodyMeasurementDetailScreen> createState() =>
      _BodyMeasurementDetailScreenState();
}

class _BodyMeasurementDetailScreenState
    extends State<BodyMeasurementDetailScreen> {
  late BodyMeasurement _measurement;
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _measurement = widget.measurement;
    _valueController = TextEditingController(
      text: _measurement.displayValue == 0.0
          ? ''
          : _measurement.displayValue.toStringAsFixed(
              _measurement.displayUnit == 'inch' ? 1 : 0,
            ),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _measurement.name,
          style: AppTextStyles.headingLarge(),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.textPrimary),
            onPressed: _showRenameDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.statusError),
            onPressed: _confirmDelete,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Value input ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusLarge,
                  ),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _valueController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        style: AppTextStyles.headingLarge(
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: AppTextStyles.headingLarge(
                            color: AppColors.textTertiary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: _onValueChanged,
                      ),
                    ),
                    // ── Unit toggle ──
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _unitChip('cm'),
                          _unitChip('inch'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // ── Info hint ──
              Text(
                'Switching units auto-converts your value.\n'
                'Values are stored in centimeters.',
                style: AppTextStyles.bodySmall(),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // ── Save button ──
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusMedium,
                    ),
                  ),
                ),
                child: Text(
                  'Save',
                  style: AppTextStyles.headingSmall(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unitChip(String unit) {
    final isSelected = _measurement.displayUnit == unit;
    return GestureDetector(
      onTap: () => _switchUnit(unit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          unit,
          style: AppTextStyles.bodyMedium(
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ).copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _onValueChanged(String raw) {
    final value = double.tryParse(raw) ?? 0.0;
    setState(() {
      _measurement = _measurement.copyWithDisplayValue(
        value,
        _measurement.displayUnit,
      );
    });
  }

  void _switchUnit(String newUnit) {
    if (_measurement.displayUnit == newUnit) return;

    setState(() {
      _measurement = _measurement.copyWith(displayUnit: newUnit);
      // Re-format the controller text for the new unit
      final displayVal = _measurement.displayValue;
      _valueController.text = displayVal == 0.0
          ? ''
          : displayVal.toStringAsFixed(newUnit == 'inch' ? 1 : 0);
    });
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _measurement.name);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: Text('Rename', style: AppTextStyles.headingSmall()),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Measurement name',
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
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  setState(() {
                    _measurement = _measurement.copyWith(name: newName);
                  });
                }
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Save',
                style: AppTextStyles.bodyMedium(color: AppColors.accentPrimary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          title: Text('Delete?', style: AppTextStyles.headingSmall()),
          content: Text(
            'Remove "${_measurement.name}" from your measurements?',
            style: AppTextStyles.bodyMedium(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: AppTextStyles.bodyMedium()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _delete();
              },
              child: Text(
                'Delete',
                style: AppTextStyles.bodyMedium(color: AppColors.statusError),
              ),
            ),
          ],
        );
      },
    );
  }

  void _delete() {
    final updated = widget.allMeasurements
        .where((m) => m.id != _measurement.id)
        .toList();
    final jsonList = updated.map((m) => m.toJson()).toList();
    context.read<BrutlUserProvider>().updateBodyMeasurements(jsonList);
    Navigator.of(context).pop();
  }

  void _save() {
    final updated = widget.allMeasurements.map((m) {
      if (m.id == _measurement.id) {
        return _measurement;
      }
      return m;
    }).toList();
    final jsonList = updated.map((m) => m.toJson()).toList();
    context.read<BrutlUserProvider>().updateBodyMeasurements(jsonList);
    Navigator.of(context).pop();
  }
}
