import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../domain/encoders/ac/ac_encoder_registry.dart';
import '../../../../domain/models/ac_device.dart';
import '../../../../domain/repositories/ac_device_repository.dart';
import '../../../../domain/use_cases/get_hardware_status_use_case.dart';
import '../../../../domain/use_cases/transmit_ac_state_use_case.dart';
import '../../../core/transmit_error.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this.repository,
    required this.registry,
    required this.transmitAcState,
    required this.getHardwareStatus,
  });

  final AcDeviceRepository repository;
  final AcEncoderRegistry registry;
  final TransmitAcStateUseCase transmitAcState;
  final GetHardwareStatusUseCase getHardwareStatus;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<AcDevice> _devices = const [];
  List<AcDevice> get devices => _devices;

  /// `null` until the hardware check finishes.
  bool? _hasEmitter;
  bool? get hasEmitter => _hasEmitter;

  final Set<String> _sending = {};
  bool isSending(AcDevice device) => _sending.contains(device.id);

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

  /// One-tap power toggle from the device card.
  Future<void> togglePower(AcDevice device) async {
    if (_sending.contains(device.id)) return;
    HapticFeedback.mediumImpact().ignore();
    final next = device.state.copyWith(isPowerOn: !device.state.isPowerOn);
    _sending.add(device.id);
    _error = null;
    notifyListeners();
    try {
      await transmitAcState.execute(device.codeId, next);
      await repository.save(device.copyWith(state: next));
      _devices = await repository.getAll();
    } catch (e) {
      _error = describeTransmitError(e);
    } finally {
      _sending.remove(device.id);
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
