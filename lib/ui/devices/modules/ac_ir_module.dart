import 'package:flutter/material.dart';

import '../../../domain/devices/device.dart';
import '../../../domain/models/ac_device.dart';
import '../../../domain/services/ac_send_queue.dart';
import '../../core/theme/ac_style.dart';
import '../../core/theme/app_colors.dart';
import '../../core/transmit_error.dart';
import '../../features/ac_pairing/view_models/ac_pairing_view_model.dart';
import '../../features/ac_pairing/views/ac_pairing_view.dart';
import '../../features/ac_remote/view_models/ac_remote_view_model.dart';
import '../../features/ac_remote/views/ac_remote_view.dart';
import '../device_module.dart';

/// Air conditioners driven by the phone's IR blaster.
class AcIrModule implements DeviceModule {
  AcIrModule({
    required this.sendQueue,
    required this.createPairingViewModel,
    required this.createRemoteViewModel,
  });

  final AcSendQueue sendQueue;
  final AcPairingViewModel Function() createPairingViewModel;
  final AcRemoteViewModel Function(AcDevice device) createRemoteViewModel;

  @override
  bool handles(Device device) => AcDevice.isAc(device);

  @override
  DeviceCardInfo cardInfo(Device device) {
    final state = AcDevice.fromDevice(device).state;
    final on = state.isPowerOn;
    return DeviceCardInfo(
      icon: on ? state.mode.icon : Icons.ac_unit_rounded,
      accent: on ? state.mode.color : AppColors.textMuted,
      summary: state.summary,
      isOn: on,
    );
  }

  @override
  Future<String?> Function()? quickToggle(Device device) => () async {
        final ac = AcDevice.fromDevice(device);
        final current = sendQueue.deliveredState(ac);
        final result = await sendQueue.send(ac, current.copyWith(isPowerOn: !current.isPowerOn));
        return result.delivered ? null : describeTransmitError(result.error!);
      };

  @override
  Future<void> open(BuildContext context, Device device) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AcRemoteView(viewModel: createRemoteViewModel(AcDevice.fromDevice(device))),
      ),
    );
  }

  @override
  bool get opensWhenAdded => true;

  @override
  Future<void> onRemoved(Device device) async => sendQueue.forget(device.id);

  @override
  List<AddDeviceOption> get addOptions => [
        AddDeviceOption(
          kind: DeviceKind.airConditioner,
          title: 'Air conditioner with an IR remote',
          subtitle: 'Find its code: pick the brand, or let auto search try every code.',
          icon: Icons.settings_remote_rounded,
          start: (context) async {
            final ac = await Navigator.of(context).push<AcDevice>(
              MaterialPageRoute(builder: (_) => AcPairingView(viewModel: createPairingViewModel())),
            );
            return ac?.toDevice();
          },
        ),
      ];
}
