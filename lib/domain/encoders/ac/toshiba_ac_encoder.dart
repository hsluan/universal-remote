import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';
import '../pulse_train.dart';
import 'ac_protocol_encoder.dart';

/// Toshiba air conditioner protocol, as IRremoteESP8266's `IRToshibaAC`.
///
/// Messages are sent MSB first, twice each. The normal message is 9 bytes;
/// turbo needs the 10-byte long form. There is no power bit: mode 7 means off.
/// Vertical swing travels in a separate 7-byte message, appended when it changed.
class ToshibaAcEncoder implements AcFrameEncoder {
  const ToshibaAcEncoder();

  static const int frequency = 38000;
  static const int headerMark = 4400;
  static const int headerSpace = 4300;
  static const int bitMark = 580;
  static const int gap = 7400;
  static const int copies = 2;

  static const BitTiming bitTiming = BitTiming.pulseDistance(mark: bitMark, oneSpace: 1600, zeroSpace: 490);

  static const int minTemperature = 17;
  static const int _modeOff = 7;
  static const int _swingOn = 1;
  static const int _swingOff = 2;
  static const int _turbo = 1;

  @override
  String get id => 'toshiba_ac';

  @override
  String get label => 'Toshiba';

  @override
  AcCapabilities get capabilities => const AcCapabilities(
        minTemperature: minTemperature,
        maxTemperature: 30,
        turbo: true,
      );

  /// The 9-byte normal message, or the 10-byte long one when turbo is on.
  @override
  List<int> buildFrame(AcState input) {
    final state = capabilities.normalize(input);
    final long = state.isPowerOn && state.turbo;
    final frame = [
      0xF2,
      0x0D,
      long ? 0x04 : 0x03, // Length nibble: total bytes - 6
      0x00,
      long ? 0x09 : 0x01, // Bit 3 marks the long message
      ((state.temperature - minTemperature) & 0x0F) << 4,
      (state.isPowerOn ? _modeValue(state.mode) : _modeOff) | (_fanValue(state.fanSpeed) << 5),
      0x00,
      if (long) _turbo,
      0x00,
    ];
    return _finish(frame);
  }

  /// The 7-byte swing message; the original remote sends it with the minimum temperature.
  static List<int> swingFrame({required bool on}) {
    return _finish([0xF2, 0x0D, 0x01, 0x00, 0x21, on ? _swingOn : _swingOff, 0x00]);
  }

  /// Byte 3 = ~byte 2, then the last byte = XOR of all others.
  static List<int> _finish(List<int> frame) {
    frame[1] = ~frame[0] & 0xFF;
    frame[3] = ~frame[2] & 0xFF;
    var xor = 0;
    for (var i = 0; i < frame.length - 1; i++) {
      xor ^= frame[i];
    }
    frame[frame.length - 1] = xor;
    return frame;
  }

  @override
  IrPacket encode(AcState state, {AcState? previous}) {
    final normalized = capabilities.normalize(state);
    final train = PulseTrain();
    final extras = <String>[];
    _send(train, buildFrame(normalized));
    if (previous != null && normalized.isPowerOn && previous.swingVertical != normalized.swingVertical) {
      _send(train, swingFrame(on: normalized.swingVertical));
      extras.add('swing ${normalized.swingVertical ? 'on' : 'off'}');
    }
    return IrPacket(frequency: frequency, pattern: train.build(), name: packetName(label, normalized, extras));
  }

  static void _send(PulseTrain train, List<int> frame) {
    for (var i = 0; i < copies; i++) {
      train
        ..mark(headerMark)
        ..space(headerSpace)
        ..bytes(frame, bitTiming, msbFirst: true)
        ..mark(bitMark)
        ..space(gap);
    }
  }

  static int _modeValue(AcMode mode) => switch (mode) {
        AcMode.auto => 0,
        AcMode.cool => 1,
        AcMode.dry => 2,
        AcMode.heat => 3,
        AcMode.fan => 4,
      };

  /// Raw fan: 0 auto, speeds 1..5 stored as 2..6; UI speeds use 1, 3 and 5.
  static int _fanValue(AcFanSpeed speed) => switch (speed) {
        AcFanSpeed.auto => 0,
        AcFanSpeed.low => 1 + 1,
        AcFanSpeed.medium => 3 + 1,
        AcFanSpeed.high => 5 + 1,
      };
}
