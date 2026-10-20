import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';
import '../pulse_train.dart';
import 'ac_protocol_encoder.dart';

/// Panasonic remote families that change model marker bytes in the frame.
enum PanasonicAcModel {
  /// DKE / DKW / PKR series, A75C2616 / A75C3704 / PN1122V remotes; has horizontal swing.
  dke,

  /// JKE series, IRremoteESP8266's default model; no horizontal swing.
  jke,

  /// NKE series; horizontal swing fixed to middle.
  nke,
}

/// Panasonic air conditioner protocol (216 bits / 27 bytes), as IRremoteESP8266's `IRPanasonicAc`.
///
/// Two sections (bytes 0-7, then 8-26), each with a 3456/1728 µs header,
/// pulse-distance bits LSB first, and a 432 µs footer mark; 10 ms between
/// sections. Checksum: byte 26 = 0xF4 + sum of bytes 0-25.
class PanasonicAcEncoder implements AcFrameEncoder {
  const PanasonicAcEncoder({this.model = PanasonicAcModel.dke});

  final PanasonicAcModel model;

  static const int frequency = 36700;
  static const int headerMark = 3456;
  static const int headerSpace = 1728;
  static const int bitMark = 432;
  static const int sectionGap = 10000;
  static const int section1Length = 8;
  static const int checksumInit = 0xF4;

  static const BitTiming bitTiming = BitTiming.pulseDistance(mark: bitMark, oneSpace: 1296, zeroSpace: 432);

  /// `kPanasonicKnownGoodState`; byte 26 is the checksum placeholder.
  static const List<int> knownGoodState = [
    0x02, 0x20, 0xE0, 0x04, 0x00, 0x00, 0x00, 0x06, 0x02, //
    0x20, 0xE0, 0x04, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00,
    0x00, 0x0E, 0xE0, 0x00, 0x00, 0x81, 0x00, 0x00, 0x00,
  ];

  /// The unit ignores the target in fan mode; the original remote sends 27 °C.
  static const int fanModeTemperature = 27;

  static const int _swingVAuto = 0xF;
  static const int _swingVMiddle = 0x3;
  static const int _swingHAuto = 0xD;
  static const int _swingHMiddle = 0x6;
  static const int _fanDelta = 3;

  @override
  String get id => 'panasonic_${model.name}';

  @override
  String get label => 'Panasonic (${model.name.toUpperCase()})';

  @override
  AcCapabilities get capabilities => AcCapabilities(
        minTemperature: 16,
        maxTemperature: 30,
        swingHorizontal: model == PanasonicAcModel.dke,
        turbo: true,
      );

  @override
  List<int> buildFrame(AcState input) {
    final state = capabilities.normalize(input);
    final frame = [...knownGoodState];

    // setModel(): the reset shared by every model, then the model's markers.
    frame[17] = 0x00;
    frame[21] &= 0xEF;
    frame[23] = 0x81;
    frame[25] = 0x00;
    switch (model) {
      case PanasonicAcModel.dke:
        frame[23] = 0x01;
        frame[25] = 0x06;
        frame[17] = state.swingHorizontal ? _swingHAuto : _swingHMiddle;
      case PanasonicAcModel.jke:
        break;
      case PanasonicAcModel.nke:
        frame[17] = _swingHMiddle;
    }

    frame[13] = (_modeValue(state.mode) << 4) | (state.isPowerOn ? 0x01 : 0x00);
    final temperature = state.mode == AcMode.fan ? fanModeTemperature : state.temperature;
    frame[14] = (temperature & 0x1F) << 1;
    final swingV = state.swingVertical ? _swingVAuto : _swingVMiddle;
    frame[16] = ((_fanValue(state.fanSpeed) + _fanDelta) << 4) | swingV;
    if (state.turbo) frame[21] |= 1 << 5;

    frame[26] = sumBytes(frame.take(26), checksumInit);
    return frame;
  }

  @override
  IrPacket encode(AcState state, {AcState? previous}) {
    final frame = buildFrame(state);
    final train = PulseTrain()
      ..mark(headerMark)
      ..space(headerSpace)
      ..bytes(frame.take(section1Length), bitTiming)
      ..mark(bitMark)
      ..space(sectionGap)
      ..mark(headerMark)
      ..space(headerSpace)
      ..bytes(frame.skip(section1Length), bitTiming)
      ..mark(bitMark);
    return IrPacket(frequency: frequency, pattern: train.build(), name: '$label ${state.isPowerOn ? 'on' : 'off'}');
  }

  static int _modeValue(AcMode mode) => switch (mode) {
        AcMode.auto => 0,
        AcMode.dry => 2,
        AcMode.cool => 3,
        AcMode.heat => 4,
        AcMode.fan => 6,
      };

  /// UI speeds span the remote's five levels: min, medium, max (auto = 7).
  static int _fanValue(AcFanSpeed speed) => switch (speed) {
        AcFanSpeed.auto => 7,
        AcFanSpeed.low => 0,
        AcFanSpeed.medium => 2,
        AcFanSpeed.high => 4,
      };
}
