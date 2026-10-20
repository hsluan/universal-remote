import '../models/ir_packet.dart';
import 'ir_protocol_encoder.dart';
import 'pulse_train.dart';

/// Bit length variants of Sony SIRC.
enum SircVariant {
  /// 7-bit command + 5-bit device.
  bits12(deviceBits: 5, extendedBits: 0),

  /// 7-bit command + 8-bit device.
  bits15(deviceBits: 8, extendedBits: 0),

  /// 7-bit command + 5-bit device + 8-bit extended device.
  bits20(deviceBits: 5, extendedBits: 8);

  const SircVariant({required this.deviceBits, required this.extendedBits});

  final int deviceBits;
  final int extendedBits;
}

/// Sony SIRC protocol (40 kHz, pulse-width coding, LSB first).
///
/// Frame: `{40k,600}<1,-1|2,-1>(4,-1,F:7,D:5|8,[E:8],^45m)`. Sony devices only
/// accept a command seen in at least three consecutive frames, so [encode]
/// emits [frames] frames on a 45 ms period.
class SonySircEncoder implements IrProtocolEncoder {
  const SonySircEncoder({
    required this.device,
    required this.command,
    this.variant = SircVariant.bits12,
    this.extended = 0,
    this.frames = 3,
    this.name = 'Sony SIRC',
  }) : assert(frames >= 1, 'SIRC needs at least one frame');

  /// Sony TV Power toggle (SIRC-12, device 1, function 21).
  factory SonySircEncoder.tvPower() {
    return const SonySircEncoder(device: 1, command: 21, name: 'Sony TV Power');
  }

  final int device;
  final int command;
  final SircVariant variant;
  final int extended;
  final int frames;
  final String name;

  static const int frequency = 40000;
  static const int headerMark = 2400;
  static const int headerSpace = 600;
  static const int framePeriod = 45000;

  static const BitTiming bitTiming = BitTiming(
    oneMark: 1200,
    oneSpace: 600,
    zeroMark: 600,
    zeroSpace: 600,
  );

  @override
  IrPacket encode() {
    final train = PulseTrain();
    for (var i = 0; i < frames; i++) {
      final start = train.durationMicros;
      train
        ..mark(headerMark)
        ..space(headerSpace)
        ..bits(command, 7, bitTiming)
        ..bits(device, variant.deviceBits, bitTiming)
        ..bits(extended, variant.extendedBits, bitTiming);
      // Pad the frame's last space up to the fixed frame period.
      train.space(framePeriod - (train.durationMicros - start));
    }
    return IrPacket(frequency: frequency, pattern: train.build(), name: name);
  }
}
