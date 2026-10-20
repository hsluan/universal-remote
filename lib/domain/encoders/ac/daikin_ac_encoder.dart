import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';
import '../pulse_train.dart';
import 'ac_protocol_encoder.dart';

/// Daikin 280-bit protocol (35 bytes), as IRremoteESP8266's `IRDaikinESP`.
///
/// Remotes ARC433**, ARC466A12, ARC466A33, ARC443A5 (M series, FTXM-M units).
/// Transmission: a 5-bit zero leader without header, then three sections
/// (bytes 0-7, 8-15, 16-34), each with a 3650/1623 µs header, bits LSB first
/// and a 428 µs footer mark followed by a 29.4 ms gap. Each section's last
/// byte is the sum of its other bytes.
class DaikinAcEncoder implements AcFrameEncoder {
  const DaikinAcEncoder();

  static const int frequency = 38000;
  static const int headerMark = 3650;
  static const int headerSpace = 1623;
  static const int bitMark = 428;
  static const int zeroSpace = 428;
  static const int oneSpace = 1280;
  static const int gap = 29000;
  static const int leaderBits = 5;

  static const BitTiming bitTiming = BitTiming.pulseDistance(mark: bitMark, oneSpace: oneSpace, zeroSpace: zeroSpace);

  /// `IRDaikinESP::stateReset()` with checksums.
  static const List<int> defaultState = [
    0x11, 0xDA, 0x27, 0x00, 0xC5, 0x00, 0x00, 0xD7, //
    0x11, 0xDA, 0x27, 0x00, 0x42, 0x00, 0x00, 0x54,
    0x11, 0xDA, 0x27, 0x00, 0x00, 0x49, 0x1E, 0x00, 0xB0, 0x00, 0x00, 0x06, 0x60, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x4F,
  ];

  static const List<int> sectionEnds = [8, 16, 35];

  static const int _swingOn = 0x0F;
  static const int _fanAuto = 0x0A;

  @override
  String get id => 'daikin';

  @override
  String get label => 'Daikin (ARC433 / ARC466)';

  @override
  AcCapabilities get capabilities => const AcCapabilities(
        minTemperature: 18,
        maxTemperature: 32,
        swingHorizontal: true,
        turbo: true,
      );

  @override
  List<int> buildFrame(AcState input) {
    final state = capabilities.normalize(input);
    final frame = [...defaultState];

    // Byte 21: power (bit 0), bit 3 always set, mode (bits 4-6).
    frame[21] = (_modeValue(state.mode) << 4) | 0x08 | (state.isPowerOn ? 0x01 : 0x00);
    // Byte 22: temperature in half degrees.
    frame[22] = state.temperature * 2;
    // Byte 24: fan (high nibble), vertical swing (low nibble).
    frame[24] = (_fanValue(state.fanSpeed) << 4) | (state.swingVertical ? _swingOn : 0x00);
    // Byte 25: horizontal swing (low nibble).
    frame[25] = state.swingHorizontal ? _swingOn : 0x00;
    // Byte 29: powerful (bit 0); quiet (bit 5) stays off.
    frame[29] = state.turbo ? 0x01 : 0x00;

    var start = 0;
    for (final end in sectionEnds) {
      frame[end - 1] = sumBytes(frame.sublist(start, end - 1));
      start = end;
    }
    return frame;
  }

  @override
  IrPacket encode(AcState state, {AcState? previous}) {
    final frame = buildFrame(state);
    final train = PulseTrain()
      ..bits(0, leaderBits, bitTiming)
      ..mark(bitMark)
      ..space(zeroSpace + gap);
    var start = 0;
    for (final end in sectionEnds) {
      train
        ..mark(headerMark)
        ..space(headerSpace)
        ..bytes(frame.sublist(start, end), bitTiming)
        ..mark(bitMark)
        ..space(zeroSpace + gap);
      start = end;
    }
    return IrPacket(frequency: frequency, pattern: train.build(), name: '$label ${state.isPowerOn ? 'on' : 'off'}');
  }

  static int _modeValue(AcMode mode) => switch (mode) {
        AcMode.auto => 0,
        AcMode.dry => 2,
        AcMode.cool => 3,
        AcMode.heat => 4,
        AcMode.fan => 6,
      };

  /// Numeric speeds 1..5 are stored as 2 + speed; UI speeds use 1, 3 and 5.
  static int _fanValue(AcFanSpeed speed) => switch (speed) {
        AcFanSpeed.auto => _fanAuto,
        AcFanSpeed.low => 2 + 1,
        AcFanSpeed.medium => 2 + 3,
        AcFanSpeed.high => 2 + 5,
      };
}
