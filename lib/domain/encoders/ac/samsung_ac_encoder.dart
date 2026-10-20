import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';
import '../pulse_train.dart';
import 'ac_protocol_encoder.dart';

/// Samsung air conditioner protocol, as IRremoteESP8266's `IRSamsungAc`.
///
/// Always sends the 21-byte extended message (three 7-byte sections), which
/// carries power changes; it is what the library sends when the previous
/// power state is unknown, so it works whether the unit was on or off.
class SamsungAcEncoder implements AcFrameEncoder {
  const SamsungAcEncoder();

  static const int frequency = 38000;
  static const int headerMark = 690;
  static const int headerSpace = 17844;
  static const int sectionMark = 3086;
  static const int sectionSpace = 8864;
  static const int sectionGap = 2886;
  static const int bitMark = 586;
  static const int sectionLength = 7;

  static const BitTiming bitTiming = BitTiming.pulseDistance(mark: bitMark, oneSpace: 1432, zeroSpace: 436);

  /// 14-byte settings state after `stateReset()` (checksums recomputed on build).
  static const List<int> defaultState = [
    0x02, 0x92, 0x0F, 0x00, 0x00, 0x00, 0xF0, //
    0x01, 0x02, 0xAF, 0x71, 0x00, 0x15, 0xF0,
  ];

  /// Middle section inserted to form the extended message.
  static const List<int> extendedMiddleSection = [0x01, 0xD2, 0x0F, 0x00, 0x00, 0x00, 0x00];

  static const int minTemperature = 16;

  @override
  String get id => 'samsung_ac';

  @override
  String get label => 'Samsung';

  @override
  AcCapabilities get capabilities => const AcCapabilities(
        minTemperature: minTemperature,
        maxTemperature: 30,
        swingHorizontal: true,
      );

  /// The 21-byte extended message.
  @override
  List<int> buildFrame(AcState input) {
    final state = capabilities.normalize(input);
    final settings = [...defaultState];
    final power = state.isPowerOn ? 0x30 : 0x00;
    settings[6] = (settings[6] & 0xCF) | power; // Power1
    settings[13] = (settings[13] & 0xCF) | power; // Power2
    settings[9] = (settings[9] & 0x8F) | (_swingValue(state) << 4);
    settings[11] = (settings[11] & 0x0F) | (((state.temperature - minTemperature) & 0x0F) << 4);
    final fan = state.mode == AcMode.auto ? 6 : _fanValue(state.fanSpeed); // Auto mode needs "Auto2"
    settings[12] = 0x01 | (fan << 1) | (_modeValue(state.mode) << 4);

    final frame = [
      ...settings.sublist(0, sectionLength),
      ...extendedMiddleSection,
      ...settings.sublist(sectionLength),
    ];
    for (var offset = 0; offset < frame.length; offset += sectionLength) {
      _writeSectionChecksum(frame, offset);
    }
    return frame;
  }

  /// Popcount of the section minus its checksum nibbles, inverted. The upper
  /// nibble goes to the low nibble of byte 2, the lower to the high nibble of byte 1.
  static int sectionChecksum(List<int> frame, int offset) {
    var bits = _popcount(frame[offset]);
    bits += _popcount(frame[offset + 1] & 0x0F);
    bits += _popcount(frame[offset + 2] >> 4);
    for (var i = 3; i < sectionLength; i++) {
      bits += _popcount(frame[offset + i]);
    }
    return (bits ^ 0xFF) & 0xFF;
  }

  static void _writeSectionChecksum(List<int> frame, int offset) {
    final sum = sectionChecksum(frame, offset);
    frame[offset + 1] = (frame[offset + 1] & 0x0F) | ((sum & 0x0F) << 4);
    frame[offset + 2] = (frame[offset + 2] & 0xF0) | (sum >> 4);
  }

  static int _popcount(int value) {
    var count = 0;
    for (var v = value & 0xFF; v != 0; v >>= 1) {
      count += v & 1;
    }
    return count;
  }

  @override
  IrPacket encode(AcState state, {AcState? previous}) {
    final frame = buildFrame(state);
    final train = PulseTrain()
      ..mark(headerMark)
      ..space(headerSpace);
    for (var offset = 0; offset < frame.length; offset += sectionLength) {
      train
        ..mark(sectionMark)
        ..space(sectionSpace)
        ..bytes(frame.sublist(offset, offset + sectionLength), bitTiming)
        ..mark(bitMark)
        ..space(sectionGap);
    }
    return IrPacket(frequency: frequency, pattern: train.build(), name: '$label ${state.isPowerOn ? 'on' : 'off'}');
  }

  static int _swingValue(AcState state) {
    if (state.swingVertical && state.swingHorizontal) return 0x4;
    if (state.swingVertical) return 0x2;
    if (state.swingHorizontal) return 0x3;
    return 0x7;
  }

  static int _modeValue(AcMode mode) => switch (mode) {
        AcMode.auto => 0,
        AcMode.cool => 1,
        AcMode.dry => 2,
        AcMode.fan => 3,
        AcMode.heat => 4,
      };

  static int _fanValue(AcFanSpeed speed) => switch (speed) {
        AcFanSpeed.auto => 0,
        AcFanSpeed.low => 2,
        AcFanSpeed.medium => 4,
        AcFanSpeed.high => 5,
      };
}
