import '../models/ir_packet.dart';
import 'ir_protocol_encoder.dart';
import 'pulse_train.dart';

/// Panasonic TV protocol (48-bit Kaseikyo frame with the Panasonic vendor id).
///
/// Frame: `{37k,432}<1,-1|1,-3>(8,-4,2:8,32:8,D:8,S:8,F:8,(D^S^F):8,1)`, LSB first.
/// For the air-conditioner protocol see `PanasonicAcEncoder`.
class PanasonicEncoder implements IrProtocolEncoder {
  const PanasonicEncoder({
    required this.device,
    required this.subdevice,
    required this.command,
    this.name = 'Panasonic',
  });

  /// Panasonic TV Power toggle (device 128, subdevice 0, function 61).
  factory PanasonicEncoder.tvPower() {
    return const PanasonicEncoder(device: 128, subdevice: 0, command: 61, name: 'Panasonic TV Power');
  }

  final int device;
  final int subdevice;
  final int command;
  final String name;

  static const int frequency = 37000;
  static const int unit = 432;
  static const int headerMark = 8 * unit;
  static const int headerSpace = 4 * unit;

  /// Panasonic's Kaseikyo vendor id, sent LSB first as 0x02, 0x20.
  static const List<int> vendorBytes = [0x02, 0x20];

  static const BitTiming bitTiming = BitTiming.pulseDistance(
    mark: unit,
    oneSpace: 3 * unit,
    zeroSpace: unit,
  );

  List<int> get bytes {
    final d = device & 0xFF;
    final s = subdevice & 0xFF;
    final f = command & 0xFF;
    return [...vendorBytes, d, s, f, d ^ s ^ f];
  }

  @override
  IrPacket encode() {
    final train = PulseTrain()
      ..mark(headerMark)
      ..space(headerSpace)
      ..bytes(bytes, bitTiming)
      ..mark(unit);
    return IrPacket(frequency: frequency, pattern: train.build(), name: name);
  }
}
