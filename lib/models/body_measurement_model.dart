import 'dart:math';

/// A single body-part measurement (e.g. Chest, Arms, Waist).
/// The canonical value is always stored in **centimeters**.
/// Display unit (cm / inch) is per-measurement choice.
class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.name,
    required this.valueCm,
    this.displayUnit = 'cm',
  });

  final String id;
  final String name;
  final double valueCm; // canonical storage unit
  final String displayUnit; // 'cm' or 'inch'

  static const double _cmPerInch = 2.54;

  /// Convert canonical CM value to the current display unit.
  double get displayValue {
    if (displayUnit == 'inch') {
      return valueCm / _cmPerInch;
    }
    return valueCm;
  }

  String get formattedDisplay {
    final v = displayValue;
    // Show 1 decimal for inches, 0 for cm (or 1 if not whole)
    if (displayUnit == 'inch') {
      return '${v.toStringAsFixed(1)} $displayUnit';
    }
    return '${v.toStringAsFixed(0)} $displayUnit';
  }

  /// Create a copy with an updated display value (converts back to CM).
  BodyMeasurement copyWithDisplayValue(double newDisplayValue, String unit) {
    final newCm = unit == 'inch'
        ? newDisplayValue * _cmPerInch
        : newDisplayValue;
    return BodyMeasurement(
      id: id,
      name: name,
      valueCm: newCm,
      displayUnit: unit,
    );
  }

  BodyMeasurement copyWith({
    String? id,
    String? name,
    double? valueCm,
    String? displayUnit,
  }) {
    return BodyMeasurement(
      id: id ?? this.id,
      name: name ?? this.name,
      valueCm: valueCm ?? this.valueCm,
      displayUnit: displayUnit ?? this.displayUnit,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'value_cm': valueCm,
      'display_unit': displayUnit,
    };
  }

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      valueCm: (json['value_cm'] as num?)?.toDouble() ?? 0.0,
      displayUnit: json['display_unit'] as String? ?? 'cm',
    );
  }

  /// Default starter set for new users.
  static List<BodyMeasurement> defaults() {
    return [
      BodyMeasurement(id: _uuid(), name: 'Chest', valueCm: 40 * _cmPerInch, displayUnit: 'cm'),
      BodyMeasurement(id: _uuid(), name: 'Thigh', valueCm: 45 * _cmPerInch, displayUnit: 'cm'),
      BodyMeasurement(id: _uuid(), name: 'Arms', valueCm: 16 * _cmPerInch, displayUnit: 'inch'),
      BodyMeasurement(id: _uuid(), name: 'Waist', valueCm: 38 * _cmPerInch, displayUnit: 'inch'),
    ];
  }

  static String _uuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(999999);
    return 'bm_${now}_$rnd';
  }
}
