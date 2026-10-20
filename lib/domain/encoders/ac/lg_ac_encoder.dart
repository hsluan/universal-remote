import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';
import '../pulse_train.dart';
import 'ac_protocol_encoder.dart';

/// LG remote families: they differ in timing and in how swing is sent.
enum LgAcModel {
  /// LG2 timing; AKB74955603 / AKB75215403 / AKB73315611 remotes. Absolute swing commands.
  lg2,

  /// LG timing; 6711A20083V / TS-H122ERM1 remotes (and GE 6711AR2853M). Swing toggle command.
  lg,
}

/// LG air conditioner protocol (28 bits, MSB first), as IRremoteESP8266's `IRLgAc`.
///
/// `0x88 | power:2 | pad | mode:3 | temp-15:4 | fan:4 | sum:4`, where sum is the
/// 4-bit sum of the four nibbles between signature and checksum. Power off is
/// a fixed command; swing is a separate command appended when it changed.
class LgAcEncoder implements AcProtocolEncoder {
  const LgAcEncoder({this.model = LgAcModel.lg2});

  final LgAcModel model;

  static const int frequency = 38000;
  static const int bits = 28;
  static const int oneSpace = 1600;
  static const int zeroSpace = 550;
  static const int minGap = 39750;
  static const int minMessageLength = 108050;

  static const int offCommand = 0x88C0051;
  static const int swingVToggle = 0x8810001;
  static const int swingVOn = 0x8813149;
  static const int swingVOff = 0x881315A;

  static const int minTemperature = 16;
  static const int _tempAdjust = 15;

  int get _headerMark => model == LgAcModel.lg2 ? 3200 : 8500;
  int get _headerSpace => model == LgAcModel.lg2 ? 9900 : 4250;
  int get _bitMark => model == LgAcModel.lg2 ? 480 : 550;

  @override
  String get id => model == LgAcModel.lg2 ? 'lg2' : 'lg';

  @override
  String get label => model == LgAcModel.lg2 ? 'LG (AKB remotes)' : 'LG (6711A remotes)';

  @override
  AcCapabilities get capabilities => const AcCapabilities(minTemperature: minTemperature, maxTemperature: 30);

  /// The 28-bit state command for [input].
  int buildCommand(AcState input) {
    final state = capabilities.normalize(input);
    if (!state.isPowerOn) return offCommand;
    final body = (_modeValue(state.mode) << 12) |
        (((state.temperature - _tempAdjust) & 0xF) << 8) |
        (_fanValue(state.fanSpeed) << 4);
    final raw = (0x88 << 20) | body; // power bits 0 = on
    return raw | checksum(raw);
  }

  /// Sum of the four nibbles in bits 4-19, modulo 16.
  static int checksum(int raw) {
    var sum = 0;
    for (var shift = 4; shift < 20; shift += 4) {
      sum += (raw >> shift) & 0xF;
    }
    return sum & 0xF;
  }

  @override
  IrPacket encode(AcState state, {AcState? previous}) {
    final normalized = capabilities.normalize(state);
    final train = PulseTrain();
    _sendCommand(train, buildCommand(normalized));
    if (normalized.isPowerOn && previous != null && previous.swingVertical != normalized.swingVertical) {
      final swing = switch (model) {
        LgAcModel.lg2 => normalized.swingVertical ? swingVOn : swingVOff,
        LgAcModel.lg => swingVToggle,
      };
      _sendCommand(train, swing);
    }
    return IrPacket(frequency: frequency, pattern: train.build(), name: '$label ${state.isPowerOn ? 'on' : 'off'}');
  }

  void _sendCommand(PulseTrain train, int command) {
    final start = train.durationMicros;
    train
      ..mark(_headerMark)
      ..space(_headerSpace)
      ..bits(command, bits, BitTiming.pulseDistance(mark: _bitMark, oneSpace: oneSpace, zeroSpace: zeroSpace),
          msbFirst: true)
      ..mark(_bitMark);
    final elapsed = train.durationMicros - start;
    // The message occupies at least 108 ms, with at least 39.75 ms of trailing gap.
    train.space(elapsed + minGap > minMessageLength ? minGap : minMessageLength - elapsed);
  }

  static int _modeValue(AcMode mode) => switch (mode) {
        AcMode.cool => 0,
        AcMode.dry => 1,
        AcMode.fan => 2,
        AcMode.auto => 3,
        AcMode.heat => 4,
      };

  static int _fanValue(AcFanSpeed speed) => switch (speed) {
        AcFanSpeed.auto => 5,
        AcFanSpeed.low => 1,
        AcFanSpeed.medium => 2,
        AcFanSpeed.high => 4,
      };
}
