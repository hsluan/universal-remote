import 'package:flutter/material.dart';

import '../../../domain/devices/device_kind.dart';

extension DeviceKindStyle on DeviceKind {
  String get label => switch (this) {
        DeviceKind.airConditioner => 'Air conditioner',
        DeviceKind.fan => 'Fan',
        DeviceKind.light => 'Light',
        DeviceKind.plug => 'Smart plug',
        DeviceKind.tv => 'TV',
        DeviceKind.camera => 'Camera',
        DeviceKind.vehicle => 'Motorbike',
      };

  /// Section title on the home list.
  String get pluralLabel => switch (this) {
        DeviceKind.airConditioner => 'Air conditioners',
        DeviceKind.fan => 'Fans',
        DeviceKind.light => 'Lights',
        DeviceKind.plug => 'Smart plugs',
        DeviceKind.tv => 'TVs',
        DeviceKind.camera => 'Cameras',
        DeviceKind.vehicle => 'Motorbikes',
      };

  IconData get icon => switch (this) {
        DeviceKind.airConditioner => Icons.ac_unit_rounded,
        DeviceKind.fan => Icons.wind_power_rounded,
        DeviceKind.light => Icons.lightbulb_rounded,
        DeviceKind.plug => Icons.power_rounded,
        DeviceKind.tv => Icons.tv_rounded,
        DeviceKind.camera => Icons.videocam_rounded,
        DeviceKind.vehicle => Icons.two_wheeler_rounded,
      };
}
