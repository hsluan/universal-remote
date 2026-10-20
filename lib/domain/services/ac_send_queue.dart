import 'dart:async';
import 'dart:collection';

import '../encoders/ac/ac_encoder_registry.dart';
import '../encoders/ac/ac_protocol_encoder.dart';
import '../models/ac_device.dart';
import '../models/ac_state.dart';
import '../repositories/ac_device_repository.dart';
import '../use_cases/transmit_ac_state_use_case.dart';

/// Outcome of [AcSendQueue.send].
class AcSendResult {
  const AcSendResult({required this.state, required this.sequence, this.error});

  /// The state that was transmitted: the one requested, or a newer request for the
  /// same AC that it was merged into.
  final AcState state;

  /// Transmission number, increasing app-wide. Requests merged into one transmission share it.
  final int sequence;

  /// Why the transmission failed; `null` when the AC was sent [state].
  final Object? error;

  bool get delivered => error == null;
}

/// Sends AC states one transmission at a time and remembers what each AC received.
///
/// - Transmissions never overlap, across all ACs: the phone has a single IR LED.
/// - While a transmission is in flight, newer requests for the same AC merge into one
///   pending state (the latest wins), so a burst of taps costs at most one more frame.
/// - Each transmission is encoded against the state the AC last received. Toggle-style
///   protocols (Midea and Coolix swing and turbo, LG and Toshiba swing) derive their
///   toggle commands from it, so a toggle goes out exactly once even when taps overlap.
/// - A delivered state is saved to the repository; after a failure the AC keeps its
///   previous state, and the next request is encoded against that.
class AcSendQueue {
  AcSendQueue({required this.registry, required this.transmitAcState, required this.repository});

  final AcEncoderRegistry registry;
  final TransmitAcStateUseCase transmitAcState;
  final AcDeviceRepository repository;

  final Map<String, _Lane> _lanes = {};
  final Queue<_Lane> _ready = Queue<_Lane>();
  bool _pumping = false;
  int _sequence = 0;

  /// Requests that [device] end up in [state]. Completes once the transmission
  /// carrying [state], or a newer state merged with it, has finished and been saved.
  Future<AcSendResult> send(AcDevice device, AcState state) {
    final lane = _laneFor(device);
    final completer = Completer<AcSendResult>();
    lane
      ..pending = lane.encoder.capabilities.normalize(state)
      ..waiters.add(completer);
    if (!_ready.contains(lane)) _ready.add(lane);
    unawaited(_pump());
    return completer.future;
  }

  /// The state [device] last received during this run, else its saved state.
  AcState deliveredState(AcDevice device) {
    final lane = _lanes[device.id];
    return lane != null && lane.encoder.id == device.codeId ? lane.delivered : device.state;
  }

  /// Drops what is known about [deviceId], e.g. after the AC was removed.
  /// A transmission already queued for it still goes out.
  void forget(String deviceId) => _lanes.remove(deviceId);

  _Lane _laneFor(AcDevice device) {
    final existing = _lanes[device.id];
    if (existing != null && existing.encoder.id == device.codeId) {
      existing.name = device.name;
      return existing;
    }
    // New, or paired again with another code.
    final encoder = registry.require(device.codeId);
    final lane = _Lane(
      deviceId: device.id,
      name: device.name,
      encoder: encoder,
      delivered: encoder.capabilities.normalize(device.state),
    );
    _lanes[device.id] = lane;
    return lane;
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_ready.isNotEmpty) {
        await _transmit(_ready.removeFirst());
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _transmit(_Lane lane) async {
    final state = lane.pending;
    final waiters = lane.waiters;
    lane
      ..pending = null
      ..waiters = [];
    if (state == null) return;

    final sequence = ++_sequence;
    AcSendResult result;
    try {
      await transmitAcState.execute(lane.encoder, state, previous: lane.delivered, source: lane.name);
      lane.delivered = state;
      result = AcSendResult(state: state, sequence: sequence);
      // Saved before the waiters resume, so a screen that reloads the list sees it.
      await _save(lane.deviceId, state);
    } catch (e) {
      result = AcSendResult(state: state, sequence: sequence, error: e);
    }
    for (final waiter in waiters) {
      waiter.complete(result);
    }
  }

  Future<void> _save(String deviceId, AcState state) async {
    try {
      await repository.update(deviceId, (device) => device.copyWith(state: state));
    } on Object {
      // The AC did receive the state; failing to save it only loses it across restarts,
      // so the send still counts as delivered.
    }
  }
}

/// Everything the queue tracks for one AC.
class _Lane {
  _Lane({required this.deviceId, required this.name, required this.encoder, required this.delivered});

  final String deviceId;
  String name;
  final AcProtocolEncoder encoder;

  /// Last state the AC received.
  AcState delivered;

  /// Latest state requested while waiting for the emitter.
  AcState? pending;

  List<Completer<AcSendResult>> waiters = [];
}
