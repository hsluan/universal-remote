import 'package:flutter/material.dart';

import '../../domain/devices/device.dart';

/// How a device looks on its home card.
class DeviceCardInfo {
  const DeviceCardInfo({required this.icon, required this.accent, required this.summary, this.isOn});

  final IconData icon;
  final Color accent;

  /// One line under the name, e.g. "Cool · 25°C · Fan auto" or "Opens Xiaomi Home".
  final String summary;

  /// `null` when the device has no on/off state to show.
  final bool? isOn;
}

/// One way to add a device, listed in the Add device screen under its [kind].
class AddDeviceOption {
  const AddDeviceOption({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.start,
    this.controlsDirectly = true,
  });

  final DeviceKind kind;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Runs the pairing flow; completes with the saved device, or `null` when cancelled.
  final Future<Device?> Function(BuildContext context) start;

  /// `false` when the app only links to another app instead of controlling the device.
  final bool controlsDirectly;
}

/// UI plug-in for the devices one integration controls (IR air conditioners, app shortcuts...).
///
/// Screens that list or add devices only talk to modules (see [DeviceModules]),
/// so a new kind of device or connection is a new module, not a change to them.
abstract interface class DeviceModule {
  bool handles(Device device);

  DeviceCardInfo cardInfo(Device device);

  /// Quick on/off from the device list, or `null` when the module has none.
  /// The returned action completes with an error message, or `null` on success.
  Future<String?> Function()? quickToggle(Device device);

  /// Opens the device's own screen (or the maker's app).
  Future<void> open(BuildContext context, Device device);

  /// Whether a newly added device is opened right away (a remote: yes; a shortcut
  /// that would leave the app: no).
  bool get opensWhenAdded;

  /// Cleans up what the module keeps outside the device list (secrets, caches)
  /// before the device is deleted.
  Future<void> onRemoved(Device device);

  List<AddDeviceOption> get addOptions;
}

/// Registry of the modules the app ships, in priority order.
class DeviceModules {
  DeviceModules(List<DeviceModule> modules) : modules = List.unmodifiable(modules);

  final List<DeviceModule> modules;

  DeviceModule? moduleFor(Device device) {
    for (final module in modules) {
      if (module.handles(device)) return module;
    }
    return null;
  }

  List<AddDeviceOption> addOptionsFor(DeviceKind kind) => [
        for (final module in modules)
          for (final option in module.addOptions)
            if (option.kind == kind) option,
      ];
}
