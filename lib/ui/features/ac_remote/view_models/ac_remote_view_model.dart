import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../domain/encoders/ac/ac_encoder_registry.dart';
import '../../../../domain/encoders/ac/ac_protocol_encoder.dart';
import '../../../../domain/models/ac_device.dart';
import '../../../../domain/models/ac_state.dart';
import '../../../../domain/repositories/ac_device_repository.dart';
import '../../../../domain/services/ac_send_queue.dart';
import '../../../core/transmit_error.dart';

class AcRemoteViewModel extends ChangeNotifier {
  AcRemoteViewModel({
    required AcDevice device,
    required AcEncoderRegistry registry,
    required this.repository,
    required this.sendQueue,
    this.temperatureDebounce = const Duration(milliseconds: 350),
  })  : _device = device,
        encoder = registry.require(device.codeId) {
    _state = encoder.capabilities.normalize(sendQueue.deliveredState(device));
  }

  final AcDeviceRepository repository;

  /// Delivers states and tracks what the AC received; it also saves the delivered state.
  final AcSendQueue sendQueue;

  final AcProtocolEncoder encoder;

  /// Rapid +/- taps are coalesced into one IR frame sent after this pause.
  final Duration temperatureDebounce;

  AcDevice _device;
  AcDevice get device => _device;

  /// The state shown and requested; the AC gets it once the queue delivers it.
  late AcState _state;
  AcState get state => _state;

  AcCapabilities get capabilities => encoder.capabilities;

  int _inFlight = 0;
  bool get isSending => _inFlight > 0;

  /// Increments once per delivered transmission; the view flashes its IR indicator on change.
  int _sentCount = 0;
  int get sentCount => _sentCount;
  int _lastSequence = 0;

  String? _error;
  String? get error => _error;

  bool get canIncrease => _state.isPowerOn && _state.temperature < capabilities.maxTemperature;
  bool get canDecrease => _state.isPowerOn && _state.temperature > capabilities.minTemperature;

  Timer? _debounce;
  bool _disposed = false;

  void togglePower() => _apply(_state.copyWith(isPowerOn: !_state.isPowerOn));

  void increaseTemperature() {
    if (!canIncrease) return;
    _apply(_state.copyWith(temperature: _state.temperature + 1), debounce: true);
  }

  void decreaseTemperature() {
    if (!canDecrease) return;
    _apply(_state.copyWith(temperature: _state.temperature - 1), debounce: true);
  }

  void setMode(AcMode mode) {
    if (mode == _state.mode) return;
    _apply(_state.copyWith(mode: mode));
  }

  void setFanSpeed(AcFanSpeed speed) {
    if (speed == _state.fanSpeed) return;
    _apply(_state.copyWith(fanSpeed: speed));
  }

  void toggleSwingVertical() => _apply(_state.copyWith(swingVertical: !_state.swingVertical));

  void toggleSwingHorizontal() => _apply(_state.copyWith(swingHorizontal: !_state.swingHorizontal));

  void toggleTurbo() => _apply(_state.copyWith(turbo: !_state.turbo));

  /// Sends the current state again, e.g. after the AC missed a command.
  Future<void> resend() => _send();

  Future<void> rename(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _device = _device.copyWith(name: trimmed);
    notifyListeners();
    // A partial update: a state the queue saves at the same time is kept.
    await repository.update(_device.id, (stored) => stored.copyWith(name: trimmed));
  }

  Future<void> delete() async {
    sendQueue.forget(_device.id);
    await repository.delete(_device.id);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _apply(AcState next, {bool debounce = false}) {
    // Every control but power is inert while the AC is off.
    if (!_state.isPowerOn && next.isPowerOn == _state.isPowerOn) return;
    HapticFeedback.selectionClick().ignore();
    _state = capabilities.normalize(next);
    _error = null;
    notifyListeners();

    _debounce?.cancel();
    if (debounce) {
      _debounce = Timer(temperatureDebounce, _send);
    } else {
      _send();
    }
  }

  Future<void> _send() async {
    _debounce?.cancel();
    _inFlight++;
    notifyListeners();
    final result = await sendQueue.send(_device, _state);
    _inFlight--;
    if (result.delivered) {
      // Requests merged into one transmission share its sequence: count it once.
      if (result.sequence != _lastSequence) {
        _lastSequence = result.sequence;
        _sentCount++;
      }
      _device = _device.copyWith(state: result.state);
      _error = null;
    } else {
      _error = describeTransmitError(result.error!);
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    // Leaving the screen right after a +/- tap must still deliver that change.
    final pending = _debounce?.isActive ?? false;
    _disposed = true;
    _debounce?.cancel();
    if (pending) _send().ignore();
    super.dispose();
  }
}
