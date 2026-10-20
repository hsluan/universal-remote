import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';
import '../pulse_train.dart';
import 'ac_protocol_encoder.dart';

/// Midea air conditioner protocol (48 bits), as IRremoteESP8266's `IRMideaAC`.
///
/// Used by many Midea-made units. Each message is sent MSB first, then again
/// bitwise inverted. Swing and turbo are not part of the state: they are
/// separate toggle messages, appended when they differ from the previous state.
class MideaAcEncoder implements AcFrameEncoder {
  const MideaAcEncoder();

  static const int frequency = 38000;
  static const int tick = 80;
  static const int headerMark = 56 * tick;
  static const int headerSpace = 56 * tick;
  static const int bitMark = 7 * tick;
  static const int minGap = 70 * tick;

  /// Gap after each normal + inverted pair (`kDefaultMessageGap`).
  static const int messageGap = 100000;

  static const BitTiming bitTiming = BitTiming.pulseDistance(mark: bitMark, oneSpace: 21 * tick, zeroSpace: 7 * tick);

  /// Toggle messages (`kMideaACToggleSwingV`, turbo toggle), byte 0 first.
  static const List<int> toggleSwingV = [0xA2, 0x01, 0xFF, 0xFF, 0xFF, 0x7C];
  static const List<int> toggleTurbo = [0xA2, 0x09, 0xFF, 0xFF, 0xFF, 0x74];

  static const int minTemperature = 17;

  @override
  String get id => 'midea';

  @override
  String get label => 'Midea';

  @override
  AcCapabilities get capabilities => const AcCapabilities(
        minTemperature: minTemperature,
        maxTemperature: 30,
        turbo: true,
      );

  /// The six state bytes in transmission order (as the 48-bit value, most significant first).
  @override
  List<int> buildFrame(AcState input) {
    final state = capabilities.normalize(input);
    final frame = [
      0xA1, // Header 0b10100, type 1 (command)
      (state.isPowerOn ? 0x80 : 0) | (_fanValue(state.fanSpeed) << 3) | _modeValue(state.mode),
      0x40 | ((state.temperature - minTemperature) & 0x1F), // Celsius (bit 5 clear)
      0xFF, // Off timer unused, beep on
      0xFF, // On timer / sensor temperature unused
      0x00,
    ];
    frame[5] = checksum(frame);
    return frame;
  }

  /// Bit-reverse bytes 0-4, sum them, negate, bit-reverse the result.
  static int checksum(List<int> frame) {
    var sum = 0;
    for (var i = 0; i < 5; i++) {
      sum += reverseBits(frame[i]);
    }
    return reverseBits((256 - (sum & 0xFF)) & 0xFF);
  }

  @override
  IrPacket encode(AcState state, {AcState? previous}) {
    final normalized = capabilities.normalize(state);
    final train = PulseTrain();
    final extras = <String>[];
    _sendMessage(train, buildFrame(normalized));
    if (previous != null && normalized.isPowerOn) {
      if (previous.swingVertical != normalized.swingVertical) {
        _sendMessage(train, toggleSwingV);
        extras.add('swing toggle');
      }
      if (previous.turbo != normalized.turbo) {
        _sendMessage(train, toggleTurbo);
        extras.add('turbo toggle');
      }
    }
    return IrPacket(frequency: frequency, pattern: train.build(), name: packetName(label, normalized, extras));
  }

  static void _sendMessage(PulseTrain train, List<int> bytes) {
    for (final inverted in [false, true]) {
      train
        ..mark(headerMark)
        ..space(headerSpace)
        ..bytes(inverted ? bytes.map((b) => ~b & 0xFF) : bytes, bitTiming, msbFirst: true)
        ..mark(bitMark)
        ..space(minGap);
    }
    train.space(messageGap);
  }

  static int _modeValue(AcMode mode) => switch (mode) {
        AcMode.cool => 0,
        AcMode.dry => 1,
        AcMode.auto => 2,
        AcMode.heat => 3,
        AcMode.fan => 4,
      };

  static int _fanValue(AcFanSpeed speed) => switch (speed) {
        AcFanSpeed.auto => 0,
        AcFanSpeed.low => 1,
        AcFanSpeed.medium => 2,
        AcFanSpeed.high => 3,
      };
}
