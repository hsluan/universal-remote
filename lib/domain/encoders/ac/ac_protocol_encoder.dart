import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';

/// What a protocol can express; the remote UI shows only these controls.
class AcCapabilities {
  const AcCapabilities({
    required this.minTemperature,
    required this.maxTemperature,
    this.modes = const {AcMode.auto, AcMode.cool, AcMode.dry, AcMode.fan, AcMode.heat},
    this.fanSpeeds = const {AcFanSpeed.auto, AcFanSpeed.low, AcFanSpeed.medium, AcFanSpeed.high},
    this.swingVertical = true,
    this.swingHorizontal = false,
    this.turbo = false,
  });

  final int minTemperature;
  final int maxTemperature;
  final Set<AcMode> modes;
  final Set<AcFanSpeed> fanSpeeds;
  final bool swingVertical;
  final bool swingHorizontal;
  final bool turbo;

  int clampTemperature(int celsius) => celsius.clamp(minTemperature, maxTemperature);

  /// Maps [state] onto what this protocol supports: clamps the temperature and
  /// falls back to supported values for everything else.
  AcState normalize(AcState state) {
    return state.copyWith(
      temperature: clampTemperature(state.temperature),
      mode: modes.contains(state.mode) ? state.mode : (modes.contains(AcMode.cool) ? AcMode.cool : modes.first),
      fanSpeed: fanSpeeds.contains(state.fanSpeed) ? state.fanSpeed : AcFanSpeed.auto,
      swingVertical: swingVertical && state.swingVertical,
      swingHorizontal: swingHorizontal && state.swingHorizontal,
      turbo: turbo && state.turbo,
    );
  }
}

/// Strategy for one AC protocol variant (one remote family).
///
/// Implementations are pure: [encode] turns a full [AcState] into the packet the
/// original remote would send for it.
abstract interface class AcProtocolEncoder {
  /// Stable identifier persisted with paired devices (e.g. `daikin`, `gree_yaw1f`).
  String get id;

  /// Human-readable remote family, shown while testing codes.
  String get label;

  AcCapabilities get capabilities;

  /// The packet for [state]. Protocols that carry some settings as toggle
  /// commands (e.g. Midea swing) compare with [previous], the last state sent,
  /// and append those commands; without [previous] only the state is sent.
  IrPacket encode(AcState state, {AcState? previous});
}

/// Encoders whose protocol carries a byte-array state frame, exposed for tests and diagnostics.
abstract interface class AcFrameEncoder implements AcProtocolEncoder {
  /// The state bytes (checksums included) for [state], after normalization.
  List<int> buildFrame(AcState state);
}

/// Sum of [bytes] modulo 256, the checksum most AC protocols use.
int sumBytes(Iterable<int> bytes, [int init = 0]) {
  var sum = init;
  for (final b in bytes) {
    sum += b;
  }
  return sum & 0xFF;
}

/// Reverses the lowest [bits] bits of [value].
int reverseBits(int value, [int bits = 8]) {
  var result = 0;
  for (var i = 0; i < bits; i++) {
    result = (result << 1) | ((value >> i) & 1);
  }
  return result;
}

/// Lowercase hex dump, e.g. `11 da 27 00`.
String hexBytes(Iterable<int> bytes) =>
    bytes.map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0')).join(' ');
