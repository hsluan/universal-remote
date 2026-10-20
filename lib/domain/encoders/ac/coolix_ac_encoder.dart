import '../../models/ac_state.dart';
import '../../models/ir_packet.dart';
import '../pulse_train.dart';
import 'ac_protocol_encoder.dart';

/// Coolix air conditioner protocol (24 bits), as IRremoteESP8266's `IRCoolixAC`.
///
/// Used by Midea-built units (Midea RG52/RG57 remotes, Beko, Bosch, some
/// Toshiba and Comfee lines). Each byte is sent MSB first followed by its
/// inverse; the frame is sent twice. Power off, swing and turbo are fixed
/// commands; swing and turbo are toggles appended when they changed.
class CoolixAcEncoder implements AcFrameEncoder {
  const CoolixAcEncoder();

  static const int frequency = 38000;
  static const int tick = 276;
  static const int headerMark = 17 * tick;
  static const int headerSpace = 16 * tick;
  static const int bitMark = 2 * tick;
  static const int minGap = 19 * tick;
  static const int messageGap = 100000;
  static const int frames = 2;

  static const BitTiming bitTiming = BitTiming.pulseDistance(mark: bitMark, oneSpace: 6 * tick, zeroSpace: 2 * tick);

  static const int offCommand = 0xB27BE0;
  static const int swingToggle = 0xB26BE0;
  static const int turboToggle = 0xB5F5A2;

  static const int minTemperature = 17;

  /// Temperature codes for 17..30 °C (not a plain offset).
  static const List<int> temperatureCodes = [
    0x0, 0x1, 0x3, 0x2, 0x6, 0x7, 0x5, 0x4, 0xC, 0xD, 0x9, 0x8, 0xA, 0xB, //
  ];

  /// Fan mode is encoded as dry mode with this temperature code.
  static const int fanModeTemperatureCode = 0xE;

  static const int _sensorIgnore = 0x1F;

  @override
  String get id => 'coolix';

  @override
  String get label => 'Coolix (Midea-made units)';

  @override
  AcCapabilities get capabilities => const AcCapabilities(
        minTemperature: minTemperature,
        maxTemperature: 30,
        turbo: true,
      );

  /// The 24-bit state command for [input].
  int buildCommand(AcState input) {
    final state = capabilities.normalize(input);
    if (!state.isPowerOn) return offCommand;
    final isFan = state.mode == AcMode.fan;
    final mode = switch (state.mode) {
      AcMode.cool => 0,
      AcMode.dry || AcMode.fan => 1,
      AcMode.auto => 2,
      AcMode.heat => 3,
    };
    final temperatureCode = isFan ? fanModeTemperatureCode : temperatureCodes[state.temperature - minTemperature];
    // Auto and dry modes use the "Auto0" fan code.
    final autoFan = state.mode == AcMode.auto || state.mode == AcMode.dry ? 0 : 5;
    final fan = switch (state.fanSpeed) {
      AcFanSpeed.auto => autoFan,
      AcFanSpeed.low => 4,
      AcFanSpeed.medium => 2,
      AcFanSpeed.high => 1,
    };
    return (0xB << 20) | (0x2 << 16) | (fan << 13) | (_sensorIgnore << 8) | (temperatureCode << 4) | (mode << 2);
  }

  /// The 24-bit state command as 3 bytes, most significant first (each is sent with its inverse).
  @override
  List<int> buildFrame(AcState state) {
    final command = buildCommand(state);
    return [(command >> 16) & 0xFF, (command >> 8) & 0xFF, command & 0xFF];
  }

  @override
  IrPacket encode(AcState state, {AcState? previous}) {
    final normalized = capabilities.normalize(state);
    final train = PulseTrain();
    final extras = <String>[];
    _sendCommand(train, buildCommand(normalized));
    if (normalized.isPowerOn && previous != null) {
      if (previous.swingVertical != normalized.swingVertical) {
        _sendCommand(train, swingToggle);
        extras.add('swing toggle');
      }
      if (previous.turbo != normalized.turbo) {
        _sendCommand(train, turboToggle);
        extras.add('turbo toggle');
      }
    }
    return IrPacket(frequency: frequency, pattern: train.build(), name: packetName(label, normalized, extras));
  }

  static void _sendCommand(PulseTrain train, int command) {
    for (var f = 0; f < frames; f++) {
      train
        ..mark(headerMark)
        ..space(headerSpace);
      for (var shift = 16; shift >= 0; shift -= 8) {
        final byte = (command >> shift) & 0xFF;
        train
          ..bits(byte, 8, bitTiming, msbFirst: true)
          ..bits(byte ^ 0xFF, 8, bitTiming, msbFirst: true);
      }
      train
        ..mark(bitMark)
        ..space(minGap);
    }
    train.space(messageGap);
  }
}
