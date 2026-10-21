import 'package:flutter/material.dart';

import '../../../domain/devices/device.dart';
import '../../../domain/devices/vendor_apps.dart';
import '../../../domain/services/app_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/device_kind_style.dart';
import '../../features/app_link/view_models/app_link_setup_view_model.dart';
import '../../features/app_link/views/app_link_setup_view.dart';
import '../device_module.dart';

/// Devices that only their maker's app can control: the card opens that app.
class AppLinkModule implements DeviceModule {
  AppLinkModule({required this.launcher, required this.createSetupViewModel});

  final AppLauncher launcher;
  final AppLinkSetupViewModel Function(DeviceKind kind) createSetupViewModel;

  @override
  bool handles(Device device) => device.connection is AppLinkConnection;

  @override
  DeviceCardInfo cardInfo(Device device) {
    final link = device.connection as AppLinkConnection;
    return DeviceCardInfo(icon: device.kind.icon, accent: AppColors.primary, summary: 'Opens ${link.appName}');
  }

  @override
  Future<String?> Function()? quickToggle(Device device) => null;

  @override
  Future<void> open(BuildContext context, Device device) async {
    final link = device.connection as AppLinkConnection;
    if (await launcher.launch(link.packageName)) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${link.appName} is not installed on this phone.'),
        action: SnackBarAction(label: 'Install', onPressed: () => launcher.openStorePage(link.packageName)),
      ));
  }

  @override
  bool get opensWhenAdded => false;

  @override
  List<AddDeviceOption> get addOptions => [
        for (final kind in DeviceKind.values)
          if (vendorAppsFor(kind).isNotEmpty)
            AddDeviceOption(
              kind: kind,
              title: "Shortcut to the maker's app",
              subtitle: 'For devices only their own app can control, e.g. ${vendorAppsFor(kind).first.name}.',
              icon: Icons.launch_rounded,
              controlsDirectly: false,
              start: (context) => Navigator.of(context).push<Device>(
                MaterialPageRoute(builder: (_) => AppLinkSetupView(viewModel: createSetupViewModel(kind))),
              ),
            ),
      ];
}
