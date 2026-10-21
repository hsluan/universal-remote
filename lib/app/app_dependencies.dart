import 'package:shared_preferences/shared_preferences.dart';

import '../data/cameras/onvif_ptz_control.dart';
import '../data/cameras/rtsp_prober.dart';
import '../data/cameras/secure_credential_store.dart';
import '../data/cameras/ws_discovery.dart';
import '../data/repositories/ac_brand_repository_impl.dart';
import '../data/repositories/device_repository_impl.dart';
import '../data/services/android_app_launcher.dart';
import '../data/services/consumer_ir_service.dart';
import '../data/services/multicast_lock.dart';
import '../domain/devices/device_kind.dart';
import '../domain/encoders/ac/ac_encoder_registry.dart';
import '../domain/encoders/ac/standard_ac_encoders.dart';
import '../domain/models/ac_device.dart';
import '../domain/repositories/ac_brand_repository.dart';
import '../domain/repositories/device_repository.dart';
import '../domain/services/ac_send_queue.dart';
import '../domain/services/app_launcher.dart';
import '../domain/services/ir_send_log.dart';
import '../domain/services/ir_transmitter.dart';
import '../domain/use_cases/get_hardware_status_use_case.dart';
import '../domain/use_cases/transmit_ac_state_use_case.dart';
import '../domain/use_cases/transmit_ir_packet_use_case.dart';
import '../ui/core/video/media_kit_live_player.dart';
import '../ui/devices/camera_services.dart';
import '../ui/devices/device_module.dart';
import '../ui/devices/modules/ac_ir_module.dart';
import '../ui/devices/modules/app_link_module.dart';
import '../ui/devices/modules/ip_camera_module.dart';
import '../ui/features/ac_pairing/view_models/ac_pairing_view_model.dart';
import '../ui/features/ac_remote/view_models/ac_remote_view_model.dart';
import '../ui/features/app_link/view_models/app_link_setup_view_model.dart';
import '../ui/features/diagnostics/view_models/diagnostics_view_model.dart';
import '../ui/features/home/view_models/home_view_model.dart';

/// Composition root: builds every service once and creates view models on demand.
class AppDependencies {
  AppDependencies({
    required this.transmitter,
    required this.devices,
    required this.acBrands,
    required this.acRegistry,
    required this.appLauncher,
    required this.cameras,
    IrSendLog? sendLog,
  })  : sendLog = sendLog ?? IrSendLog(),
        getHardwareStatus = GetHardwareStatusUseCase(transmitter: transmitter) {
    transmitPacket = TransmitIrPacketUseCase(transmitter: transmitter, log: this.sendLog);
    transmitAcState = TransmitAcStateUseCase(transmitPacket: transmitPacket);
    acSendQueue = AcSendQueue(registry: acRegistry, transmitAcState: transmitAcState, repository: devices);
    deviceModules = DeviceModules([
      AcIrModule(
        sendQueue: acSendQueue,
        createPairingViewModel: createPairingViewModel,
        createRemoteViewModel: createRemoteViewModel,
      ),
      IpCameraModule(services: cameras, repository: devices, launcher: appLauncher),
      AppLinkModule(launcher: appLauncher, createSetupViewModel: createAppLinkSetupViewModel),
    ]);
  }

  /// Production wiring: Android IR and app bridges, shared preferences, bundled catalog.
  factory AppDependencies.production() {
    return AppDependencies(
      transmitter: ConsumerIrService(),
      devices: DeviceRepositoryImpl(preferences: SharedPreferences.getInstance()),
      acBrands: AcBrandRepositoryImpl(),
      acRegistry: createStandardAcRegistry(),
      appLauncher: AndroidAppLauncher(),
      cameras: CameraServices(
        credentials: SecureCredentialStore(),
        prober: SocketRtspProber(),
        discovery: WsDiscovery(multicastLock: AndroidMulticastLock()),
        createPtz: ({required host, required port, required credentials}) =>
            OnvifPtzControl(host: host, port: port, credentials: credentials),
        createPlayer: MediaKitLivePlayer.new,
      ),
    );
  }

  final IrTransmitter transmitter;
  final DeviceRepository devices;
  final AcBrandRepository acBrands;
  final AcEncoderRegistry acRegistry;
  final AppLauncher appLauncher;

  /// Network, secure storage and video player of the camera module.
  final CameraServices cameras;
  final IrSendLog sendLog;
  final GetHardwareStatusUseCase getHardwareStatus;
  late final TransmitIrPacketUseCase transmitPacket;
  late final TransmitAcStateUseCase transmitAcState;

  /// The one path to paired ACs: shared by every screen so sends never overlap.
  late final AcSendQueue acSendQueue;

  /// One module per family of devices; screens that list or add devices go through it.
  late final DeviceModules deviceModules;

  HomeViewModel createHomeViewModel() => HomeViewModel(
        repository: devices,
        modules: deviceModules,
        getHardwareStatus: getHardwareStatus,
      );

  AcPairingViewModel createPairingViewModel() => AcPairingViewModel(
        brandRepository: acBrands,
        deviceRepository: devices,
        registry: acRegistry,
        transmitAcState: transmitAcState,
      );

  AcRemoteViewModel createRemoteViewModel(AcDevice device) => AcRemoteViewModel(
        device: device,
        registry: acRegistry,
        repository: devices,
        sendQueue: acSendQueue,
      );

  AppLinkSetupViewModel createAppLinkSetupViewModel(DeviceKind kind) => AppLinkSetupViewModel(
        kind: kind,
        launcher: appLauncher,
        repository: devices,
      );

  DiagnosticsViewModel createDiagnosticsViewModel() => DiagnosticsViewModel(
        getHardwareStatusUseCase: getHardwareStatus,
        transmitIrPacketUseCase: transmitPacket,
        sendLog: sendLog,
      );
}
