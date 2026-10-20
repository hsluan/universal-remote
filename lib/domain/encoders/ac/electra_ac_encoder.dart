import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';
import '../pulse_train.dart';
import 'ac_protocol_encoder.dart';

/// Electra air conditioner protocol (104 bits / 13 bytes, LSB first), as
/// IRremoteESP8266's `IRElectraAc`, tuned to the Casper remote.
///
/// Brands: Casper (SC-09FS32), AUX, Electra, Electrolux YKR-H/531E, Centek,
/// Subtropic, Frigidaire (YKR-* remotes).
///
/// Verified against 727 real Casper SC-09FS32 captures (SmartIR
/// `codes/climate/3240.json`, MIT): every one decodes to this layout with a
/// valid checksum. The captures also fix what the library leaves open:
/// - byte 11 is 0x40, with bit 0 set at 16 °C and 0x45 in the power-off frame;
/// - turbo is sent together with the high fan speed;
/// - timings are the Casper remote's own (medians of the captures), within
///   about 15 % of the library's AUX-derived values.
class ElectraAcEncoder implements AcFrameEncoder {
  const ElectraAcEncoder();

  static const int frequency = 38000;
  static const int headerMark = 9556;
  static const int headerSpace = 4893;
  static const int bitMark = 558;
  static const int oneSpace = 1839;
  static const int zeroSpace = 624;

  static const BitTiming bitTiming = BitTiming.pulseDistance(mark: bitMark, oneSpace: oneSpace, zeroSpace: zeroSpace);

  static const int minTemperature = 16;
  static const int _temperatureDelta = 8;
  static const int _swingOn = 0x0;
  static const int _swingOff = 0x7;
  static const int _fanHigh = 0x1;

  @override
  String get id => 'electra';

  @override
  String get label => 'Casper / Electra (YKR remotes)';

  @override
  AcCapabilities get capabilities => const AcCapabilities(
        minTemperature: minTemperature,
        maxTemperature: 32,
        swingHorizontal: true,
        turbo: true,
      );

  @override
  List<int> buildFrame(AcState input) {
    final state = capabilities.normalize(input);
    final frame = List<int>.filled(13, 0);
    frame[0] = 0xC3;
    // Byte 1: vertical swing (bits 0-2), temperature - 8 (bits 3-7).
    frame[1] = (((state.temperature - _temperatureDelta) & 0x1F) << 3) |
        (state.swingVertical ? _swingOn : _swingOff);
    // Byte 2: horizontal swing (bits 5-7).
    frame[2] = (state.swingHorizontal ? _swingOn : _swingOff) << 5;
    // Byte 4: fan (bits 5-7); byte 5: turbo (bit 6).
    frame[4] = (state.turbo ? _fanHigh : _fanValue(state.fanSpeed)) << 5;
    frame[5] = state.turbo ? 0x40 : 0x00;
    // Byte 6: mode (bits 5-7); byte 9: power (bit 5).
    frame[6] = _modeValue(state.mode) << 5;
    frame[9] = state.isPowerOn ? 0x20 : 0x00;
    // Byte 11: values the Casper remote sends (light toggle off).
    frame[11] = !state.isPowerOn ? 0x45 : (state.temperature == minTemperature ? 0x41 : 0x40);
    frame[12] = sumBytes(frame.take(12));
    return frame;
  }

  @override
  IrPacket encode(AcState state, {AcState? previous}) {
    final train = PulseTrain()
      ..mark(headerMark)
      ..space(headerSpace)
      ..bytes(buildFrame(state), bitTiming)
      ..mark(bitMark);
    return IrPacket(frequency: frequency, pattern: train.build(), name: '$label ${state.isPowerOn ? 'on' : 'off'}');
  }

  static int _modeValue(AcMode mode) => switch (mode) {
        AcMode.auto => 0x0,
        AcMode.cool => 0x1,
        AcMode.dry => 0x2,
        AcMode.heat => 0x4,
        AcMode.fan => 0x6,
      };

  static int _fanValue(AcFanSpeed speed) => switch (speed) {
        AcFanSpeed.auto => 0x5,
        AcFanSpeed.low => 0x3,
        AcFanSpeed.medium => 0x2,
        AcFanSpeed.high => _fanHigh,
      };
}
