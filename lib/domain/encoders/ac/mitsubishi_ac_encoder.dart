import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';
import '../pulse_train.dart';
import 'ac_protocol_encoder.dart';

/// Mitsubishi Electric air conditioner protocol (144 bits / 18 bytes), as
/// IRremoteESP8266's `IRMitsubishiAC`. Sent LSB first, twice.
class MitsubishiAcEncoder implements AcFrameEncoder {
  const MitsubishiAcEncoder();

  static const int frequency = 38000;
  static const int headerMark = 3400;
  static const int headerSpace = 1750;
  static const int bitMark = 450;
  static const int repeatMark = 440;
  static const int repeatSpace = 15500;
  static const int copies = 2;

  static const BitTiming bitTiming = BitTiming.pulseDistance(mark: bitMark, oneSpace: 1300, zeroSpace: 420);

  /// `IRMitsubishiAC::stateReset()`; byte 17 is the checksum.
  static const List<int> defaultState = [
    0x23, 0xCB, 0x26, 0x01, 0x00, 0x20, 0x08, 0x06, 0x30, //
    0x45, 0x67, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1F,
  ];

  static const int minTemperature = 16;
  static const int _vaneSwing = 7;
  static const int _wideVaneMiddle = 3;
  static const int _wideVaneAuto = 8;

  @override
  String get id => 'mitsubishi_ac';

  @override
  String get label => 'Mitsubishi Electric';

  @override
  AcCapabilities get capabilities => const AcCapabilities(
        minTemperature: minTemperature,
        maxTemperature: 31,
        swingHorizontal: true,
      );

  @override
  List<int> buildFrame(AcState input) {
    final state = capabilities.normalize(input);
    final frame = [...defaultState];
    frame[5] = state.isPowerOn ? 0x20 : 0x00;
    frame[6] = _modeValue(state.mode) << 3;
    frame[7] = (state.temperature - minTemperature) & 0x0F;
    // setMode() rewrites byte 8: mode-specific low nibble, wide vane in the high nibble.
    final wideVane = state.swingHorizontal ? _wideVaneAuto : _wideVaneMiddle;
    frame[8] = (wideVane << 4) | _modeByte8LowNibble(state.mode);
    // Byte 9: fan (bits 0-2), vane (bits 3-5), vane-set flag (bit 6), auto fan (bit 7).
    final fan = _fanValue(state.fanSpeed);
    final vane = state.swingVertical ? _vaneSwing : 0;
    frame[9] = fan | (vane << 3) | 0x40 | (state.fanSpeed == AcFanSpeed.auto ? 0x80 : 0);
    frame[17] = sumBytes(frame.take(17));
    return frame;
  }

  @override
  IrPacket encode(AcState state, {AcState? previous}) {
    final frame = buildFrame(state);
    final train = PulseTrain();
    for (var i = 0; i < copies; i++) {
      train
        ..mark(headerMark)
        ..space(headerSpace)
        ..bytes(frame, bitTiming)
        ..mark(repeatMark)
        ..space(repeatSpace);
    }
    return IrPacket(frequency: frequency, pattern: train.build(), name: '$label ${state.isPowerOn ? 'on' : 'off'}');
  }

  static int _modeValue(AcMode mode) => switch (mode) {
        AcMode.heat => 0x1,
        AcMode.dry => 0x2,
        AcMode.cool => 0x3,
        AcMode.auto => 0x4,
        AcMode.fan => 0x7,
      };

  static int _modeByte8LowNibble(AcMode mode) => switch (mode) {
        AcMode.auto => 0x0,
        AcMode.cool => 0x6,
        AcMode.dry => 0x2,
        AcMode.heat => 0x0,
        AcMode.fan => 0x7,
      };

  /// Raw speeds 1..4 (0 with the auto flag for auto).
  static int _fanValue(AcFanSpeed speed) => switch (speed) {
        AcFanSpeed.auto => 0,
        AcFanSpeed.low => 1,
        AcFanSpeed.medium => 3,
        AcFanSpeed.high => 4,
      };
}
