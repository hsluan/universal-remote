import 'package:flutter/material.dart';

import '../../../domain/cameras/ip_camera.dart';
import '../../../domain/devices/device.dart';
import '../../../domain/repositories/device_repository.dart';
import '../../../domain/services/app_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../features/camera_setup/view_models/camera_setup_view_model.dart';
import '../../features/camera_setup/views/camera_setup_view.dart';
import '../../features/camera_view/view_models/camera_view_model.dart';
import '../../features/camera_view/views/camera_view.dart';
import '../camera_services.dart';
import '../device_module.dart';

/// IP cameras on the home Wi-Fi: RTSP live view and ONVIF pan/tilt, no vendor cloud.
class IpCameraModule implements DeviceModule {
  IpCameraModule({required this.services, required this.repository, required this.launcher});

  final CameraServices services;
  final DeviceRepository repository;
  final AppLauncher launcher;

  @override
  bool handles(Device device) => IpCamera.isIpCamera(device);

  @override
  DeviceCardInfo cardInfo(Device device) {
    final camera = IpCamera.fromDevice(device);
    return DeviceCardInfo(
      icon: Icons.videocam_rounded,
      accent: AppColors.primary,
      summary: camera.ptz ? 'Live view · Pan/tilt' : 'Live view',
    );
  }

  @override
  Future<String?> Function()? quickToggle(Device device) => null;

  @override
  Future<void> open(BuildContext context, Device device) {
    final camera = IpCamera.fromDevice(device);
    final makerApp = camera.brand.appPackage;
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CameraView(
          viewModel: CameraViewModel(
            camera: camera,
            credentials: services.credentials,
            player: services.createPlayer(),
            createPtz: services.createPtz,
          ),
          onOpenMakerApp: makerApp == null
              ? null
              : () async {
                  if (!await launcher.launch(makerApp)) await launcher.openStorePage(makerApp);
                },
        ),
      ),
    );
  }

  @override
  bool get opensWhenAdded => true;

  @override
  Future<void> onRemoved(Device device) => services.credentials.delete(device.id);

  @override
  List<AddDeviceOption> get addOptions => [
        AddDeviceOption(
          kind: DeviceKind.camera,
          title: 'IP camera on your Wi-Fi',
          subtitle: 'Imou, EZVIZ, Tapo, Hikvision or any RTSP/ONVIF camera: live view and pan/tilt in this app.',
          icon: Icons.videocam_rounded,
          start: (context) => Navigator.of(context).push<Device>(
            MaterialPageRoute(
              builder: (_) => CameraSetupView(
                viewModel: CameraSetupViewModel(
                  repository: repository,
                  credentials: services.credentials,
                  prober: services.prober,
                  discovery: services.discovery,
                  createPtz: services.createPtz,
                ),
              ),
            ),
          ),
        ),
      ];
}
