import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../domain/devices/device.dart';
import '../../../../domain/repositories/device_repository.dart';
import '../../../../domain/use_cases/get_hardware_status_use_case.dart';
import '../../../devices/device_module.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this.repository,
    required this.modules,
    required this.getHardwareStatus,
  });

  final DeviceRepository repository;
  final DeviceModules modules;
  final GetHardwareStatusUseCase getHardwareStatus;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<Device> _devices = const [];
  List<Device> get devices => _devices;

  /// Devices grouped by kind, in [DeviceKind] order; devices no module handles are left out.
  List<(DeviceKind, List<Device>)> get sections => [
        for (final kind in DeviceKind.values)
          if (_devices.any((d) => d.kind == kind && modules.moduleFor(d) != null))
            (kind, [for (final d in _devices) if (d.kind == kind && modules.moduleFor(d) != null) d]),
      ];

  /// `null` until the hardware check finishes.
  bool? _hasEmitter;
  bool? get hasEmitter => _hasEmitter;

  bool get hasIrDevices => _devices.any((d) => d.connection is IrConnection);

  final Set<String> _sending = {};
  bool isSending(Device device) => _sending.contains(device.id);

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final status = await getHardwareStatus.execute();
      _hasEmitter = status.hasEmitter;
    } catch (_) {
      _hasEmitter = false;
    }
    await refresh();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _devices = await repository.getAll();
    notifyListeners();
  }

  /// Whether the device's card shows a power button.
  bool canToggle(Device device) => modules.moduleFor(device)?.quickToggle(device) != null;

  /// One-tap power toggle from the card. Taps while that device is sending are ignored.
  Future<void> togglePower(Device device) async {
    final action = modules.moduleFor(device)?.quickToggle(device);
    if (action == null || _sending.contains(device.id)) return;
    HapticFeedback.mediumImpact().ignore();
    _sending.add(device.id);
    _error = null;
    notifyListeners();
    _error = await action();
    _sending.remove(device.id);
    // The module saved the new state.
    await refresh();
  }

  Future<void> rename(Device device, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await repository.update(device.id, (stored) => stored.copyWith(name: trimmed));
    await refresh();
  }

  Future<void> remove(Device device) async {
    await modules.moduleFor(device)?.onRemoved(device);
    await repository.delete(device.id);
    await refresh();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
