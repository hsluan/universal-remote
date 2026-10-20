import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../domain/encoders/ac/ac_encoder_registry.dart';
import '../../../../domain/encoders/ac/ac_protocol_encoder.dart';
import '../../../../domain/models/ac_device.dart';
import '../../../../domain/models/ac_state.dart';
import '../../../../domain/repositories/ac_device_repository.dart';
import '../../../../domain/use_cases/transmit_ac_state_use_case.dart';
import '../../../core/transmit_error.dart';

class AcRemoteViewModel extends ChangeNotifier {
  AcRemoteViewModel({
    required AcDevice device,
    required AcEncoderRegistry registry,
    required this.repository,
    required this.transmitAcState,
    this.temperatureDebounce = const Duration(milliseconds: 350),
  })  : _device = device,
        encoder = registry.require(device.codeId) {
    _state = encoder.capabilities.normalize(device.state);
    _lastSent = _state;
  }

  final AcDeviceRepository repository;
  final TransmitAcStateUseCase transmitAcState;
  final AcProtocolEncoder encoder;

  /// Rapid +/- taps are coalesced into one IR frame sent after this pause.
  final Duration temperatureDebounce;

  AcDevice _device;
  AcDevice get device => _device;

  late AcState _state;
  AcState get state => _state;

  /// Last state the AC received, for protocols that send changes as toggles.
  late AcState _lastSent;

  AcCapabilities get capabilities => encoder.capabilities;

  bool _isSending = false;
  bool get isSending => _isSending;

  /// Increments on every successful transmission; the view flashes its IR indicator on change.
  int _sentCount = 0;
  int get sentCount => _sentCount;

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
    await repository.save(_device);
  }

  Future<void> delete() => repository.delete(_device.id);

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
    final sent = _state;
    _isSending = true;
    notifyListeners();
    try {
      await transmitAcState.executeWith(encoder, sent, previous: _lastSent);
      _lastSent = sent;
      _sentCount++;
      _device = _device.copyWith(state: sent);
      await repository.save(_device);
    } catch (e) {
      _error = describeTransmitError(e);
    } finally {
      _isSending = false;
      if (!_disposed) notifyListeners();
    }
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
