import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';
import '../pulse_train.dart';
import 'ac_protocol_encoder.dart';

/// Gree remote families; they differ only in byte 2 bit 6 while powered on.
enum GreeAcModel { yaw1f, ybofb }

/// Gree air conditioner protocol (64 bits / 8 bytes), as IRremoteESP8266's `IRGreeAC`.
///
/// 9000/4500 µs header, bytes 0-3 LSB first, a 3-bit `010` block footer, a
/// 19.98 ms gap, then bytes 4-7. Byte 7's high nibble is a 4-bit checksum.
class GreeAcEncoder implements AcFrameEncoder {
  const GreeAcEncoder({this.model = GreeAcModel.yaw1f});

  final GreeAcModel model;

  static const int frequency = 38000;
  static const int headerMark = 9000;
  static const int headerSpace = 4500;
  static const int bitMark = 620;
  static const int messageSpace = 19980;
  static const int blockFooter = 0x2; // 0b010, sent LSB first
  static const int blockFooterBits = 3;

  static const BitTiming bitTiming = BitTiming.pulseDistance(mark: bitMark, oneSpace: 1600, zeroSpace: 540);

  /// Auto mode always reports 25 °C on the original remote.
  static const int autoModeTemperature = 25;

  @override
  String get id => 'gree_${model.name}';

  @override
  String get label => 'Gree (${model.name.toUpperCase()})';

  @override
  AcCapabilities get capabilities => const AcCapabilities(
        minTemperature: 16,
        maxTemperature: 30,
        swingHorizontal: true,
        turbo: true,
      );

  @override
  List<int> buildFrame(AcState input) {
    final state = capabilities.normalize(input);
    final temperature = state.mode == AcMode.auto ? autoModeTemperature : state.temperature;
    // Dry mode forces the lowest fan speed.
    final fan = state.mode == AcMode.dry ? 1 : _fanValue(state.fanSpeed);
    final power = state.isPowerOn;

    final frame = List<int>.filled(8, 0);
    frame[0] = _modeValue(state.mode) |
        (power ? 0x08 : 0) |
        (fan << 4) |
        (state.swingVertical ? 0x40 : 0); // SwingAuto
    frame[1] = (temperature - 16) & 0x0F;
    frame[2] = (state.turbo ? 0x10 : 0) |
        0x20 | // Light on
        (power && model == GreeAcModel.yaw1f ? 0x40 : 0);
    frame[3] = 0x50;
    // SwingV: 1 = auto, 0 = last position. SwingH: 1 = auto, 0 = off.
    frame[4] = (state.swingVertical ? 0x01 : 0x00) | (state.swingHorizontal ? 0x10 : 0x00);
    frame[5] = 0x20;
    frame[6] = 0x00;
    frame[7] = checksum(frame) << 4;
    return frame;
  }

  /// IRremoteESP8266's Kelvinator block checksum: 10 + low nibbles of bytes
  /// 0-3 + high nibbles of bytes 4-6, modulo 16.
  static int checksum(List<int> frame) {
    var sum = 10;
    for (var i = 0; i < 4; i++) {
      sum += frame[i] & 0x0F;
    }
    for (var i = 4; i < 7; i++) {
      sum += frame[i] >> 4;
    }
    return sum & 0x0F;
  }

  @override
  IrPacket encode(AcState state, {AcState? previous}) {
    final frame = buildFrame(state);
    final train = PulseTrain()
      ..mark(headerMark)
      ..space(headerSpace)
      ..bytes(frame.take(4), bitTiming)
      ..bits(blockFooter, blockFooterBits, bitTiming)
      ..mark(bitMark)
      ..space(messageSpace)
      ..bytes(frame.skip(4), bitTiming)
      ..mark(bitMark);
    return IrPacket(frequency: frequency, pattern: train.build(), name: '$label ${state.isPowerOn ? 'on' : 'off'}');
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
        AcFanSpeed.low => 1,
        AcFanSpeed.medium => 2,
        AcFanSpeed.high => 3,
      };
}
