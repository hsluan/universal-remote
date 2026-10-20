import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/ac_brand_repository_impl.dart';
import '../data/repositories/ac_device_repository_impl.dart';
import '../data/services/consumer_ir_service.dart';
import '../domain/encoders/ac/ac_encoder_registry.dart';
import '../domain/encoders/ac/standard_ac_encoders.dart';
import '../domain/models/ac_device.dart';
import '../domain/repositories/ac_brand_repository.dart';
import '../domain/repositories/ac_device_repository.dart';
import '../domain/services/ac_send_queue.dart';
import '../domain/services/ir_send_log.dart';
import '../domain/services/ir_transmitter.dart';
import '../domain/use_cases/get_hardware_status_use_case.dart';
import '../domain/use_cases/transmit_ac_state_use_case.dart';
import '../domain/use_cases/transmit_ir_packet_use_case.dart';
import '../ui/features/ac_pairing/view_models/ac_pairing_view_model.dart';
import '../ui/features/ac_remote/view_models/ac_remote_view_model.dart';
import '../ui/features/diagnostics/view_models/diagnostics_view_model.dart';
import '../ui/features/home/view_models/home_view_model.dart';

/// Composition root: builds every service once and creates view models on demand.
class AppDependencies {
  AppDependencies({
    required this.transmitter,
    required this.acDevices,
    required this.acBrands,
    required this.acRegistry,
    IrSendLog? sendLog,
  })  : sendLog = sendLog ?? IrSendLog(),
        getHardwareStatus = GetHardwareStatusUseCase(transmitter: transmitter) {
    transmitPacket = TransmitIrPacketUseCase(transmitter: transmitter, log: this.sendLog);
    transmitAcState = TransmitAcStateUseCase(transmitPacket: transmitPacket);
    acSendQueue = AcSendQueue(registry: acRegistry, transmitAcState: transmitAcState, repository: acDevices);
  }

  /// Production wiring: Android IR bridge, shared preferences, bundled catalog.
  factory AppDependencies.production() {
    return AppDependencies(
      transmitter: ConsumerIrService(),
      acDevices: AcDeviceRepositoryImpl(preferences: SharedPreferences.getInstance()),
      acBrands: AcBrandRepositoryImpl(),
      acRegistry: createStandardAcRegistry(),
    );
  }

  final IrTransmitter transmitter;
  final AcDeviceRepository acDevices;
  final AcBrandRepository acBrands;
  final AcEncoderRegistry acRegistry;
  final IrSendLog sendLog;
  final GetHardwareStatusUseCase getHardwareStatus;
  late final TransmitIrPacketUseCase transmitPacket;
  late final TransmitAcStateUseCase transmitAcState;

  /// The one path to paired ACs: shared by every screen so sends never overlap.
  late final AcSendQueue acSendQueue;

  HomeViewModel createHomeViewModel() => HomeViewModel(
        repository: acDevices,
        sendQueue: acSendQueue,
        getHardwareStatus: getHardwareStatus,
      );

  AcPairingViewModel createPairingViewModel() => AcPairingViewModel(
        brandRepository: acBrands,
        deviceRepository: acDevices,
        registry: acRegistry,
        transmitAcState: transmitAcState,
      );

  AcRemoteViewModel createRemoteViewModel(AcDevice device) => AcRemoteViewModel(
        device: device,
        registry: acRegistry,
        repository: acDevices,
        sendQueue: acSendQueue,
      );

  DiagnosticsViewModel createDiagnosticsViewModel() => DiagnosticsViewModel(
        getHardwareStatusUseCase: getHardwareStatus,
        transmitIrPacketUseCase: transmitPacket,
        sendLog: sendLog,
      );
}
