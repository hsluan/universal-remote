import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/ac_device.dart';
import '../../../../domain/repositories/ac_device_repository.dart';
import '../../../../domain/services/ac_send_queue.dart';
import '../../../../domain/use_cases/get_hardware_status_use_case.dart';
import '../../../core/transmit_error.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this.repository,
    required this.sendQueue,
    required this.getHardwareStatus,
  });

  final AcDeviceRepository repository;
  final AcSendQueue sendQueue;
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

  /// One-tap power toggle from the device card. Taps while that AC is sending are ignored.
  Future<void> togglePower(AcDevice device) async {
    if (_sending.contains(device.id)) return;
    HapticFeedback.mediumImpact().ignore();
    final current = sendQueue.deliveredState(device);
    _sending.add(device.id);
    _error = null;
    notifyListeners();
    final result = await sendQueue.send(device, current.copyWith(isPowerOn: !current.isPowerOn));
    if (!result.delivered) _error = describeTransmitError(result.error!);
    _sending.remove(device.id);
    // The queue saved the delivered state.
    await refresh();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
