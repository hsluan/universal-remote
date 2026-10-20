import '../models/ir_packet.dart';
import 'ir_protocol_encoder.dart';
import 'pulse_train.dart';

/// Samsung32 protocol, called NECx in IRDB / IRP notation.
///
/// NEC bit coding with a shorter 4.5 ms leader mark. Samsung TVs ignore the
/// 9 ms NEC leader, so they need this encoder rather than [NecEncoder].
///
/// Frame: `{38k,560}<1,-1|1,-3>(8,-8,D:8,S:8,F:8,~F:8,1)`, LSB first.
class SamsungEncoder implements IrProtocolEncoder {
  const SamsungEncoder({
    required this.device,
    required this.subdevice,
    required this.command,
    this.name = 'Samsung32',
  });

  /// Samsung TV Power toggle (device 7, subdevice 7, function 2).
  factory SamsungEncoder.tvPower() {
    return const SamsungEncoder(device: 0x07, subdevice: 0x07, command: 0x02, name: 'Samsung TV Power');
  }

  final int device;
  final int subdevice;
  final int command;
  final String name;

  static const int frequency = 38000;
  static const int headerMark = 4480;
  static const int headerSpace = 4480;
  static const int bitMark = 560;
  static const int oneSpace = 1680;
  static const int zeroSpace = 560;

  static const BitTiming bitTiming = BitTiming.pulseDistance(
    mark: bitMark,
    oneSpace: oneSpace,
    zeroSpace: zeroSpace,
  );

  List<int> get bytes => [device & 0xFF, subdevice & 0xFF, command & 0xFF, ~command & 0xFF];

  @override
  IrPacket encode() {
    final train = PulseTrain()
      ..mark(headerMark)
      ..space(headerSpace)
      ..bytes(bytes, bitTiming)
      ..mark(bitMark);
    return IrPacket(frequency: frequency, pattern: train.build(), name: name);
  }
}
