import 'package:flutter/material.dart';

import '../../../domain/models/ac_state.dart';
import 'app_colors.dart';

extension AcModeStyle on AcMode {
  String get label => switch (this) {
        AcMode.auto => 'Auto',
        AcMode.cool => 'Cool',
        AcMode.dry => 'Dry',
        AcMode.fan => 'Fan',
        AcMode.heat => 'Heat',
      };

  IconData get icon => switch (this) {
        AcMode.auto => Icons.autorenew_rounded,
        AcMode.cool => Icons.ac_unit_rounded,
        AcMode.dry => Icons.water_drop_rounded,
        AcMode.fan => Icons.air_rounded,
        AcMode.heat => Icons.wb_sunny_rounded,
      };

  Color get color => switch (this) {
        AcMode.auto => AppColors.modeAuto,
        AcMode.cool => AppColors.modeCool,
        AcMode.dry => AppColors.modeDry,
        AcMode.fan => AppColors.modeFan,
        AcMode.heat => AppColors.modeHeat,
      };

  /// Fan-only mode ignores the target temperature on most units.
  bool get usesTemperature => this != AcMode.fan;
}

extension AcFanSpeedStyle on AcFanSpeed {
  String get label => switch (this) {
        AcFanSpeed.auto => 'Auto',
        AcFanSpeed.low => 'Low',
        AcFanSpeed.medium => 'Med',
        AcFanSpeed.high => 'High',
      };
}

extension AcStateSummary on AcState {
  /// One-line summary for device cards, e.g. "Cool · 25°C · Fan auto".
  String get summary {
    if (!isPowerOn) return 'Off';
    final parts = [
      mode.label,
      if (mode.usesTemperature) '$temperature°C',
      'Fan ${fanSpeed.label.toLowerCase()}',
    ];
    return parts.join(' · ');
  }
}
