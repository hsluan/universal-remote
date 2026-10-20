import '../models/ir_packet.dart';
import 'ir_protocol_encoder.dart';
import 'pulse_train.dart';

/// Implements the NEC Infrared Transmission Protocol (38 kHz).
///
/// Pulse timing specification:
/// - Carrier frequency: 38,000 Hz
/// - Header: 9,000 µs Mark, 4,500 µs Space
/// - Bit 0: 560 µs Mark, 560 µs Space
/// - Bit 1: 560 µs Mark, 1,690 µs Space
/// - Stop bit: 560 µs Mark
class NecEncoder implements IrProtocolEncoder {
  const NecEncoder.rawBytes({
    required this.bytes,
    this.frequency = 38000,
    this.name = 'NEC Custom',
  }) : assert(bytes.length == 4, 'NEC protocol expects exactly 4 bytes (32 bits)');

  /// Creates a standard NEC packet with 8-bit address and 8-bit command.
  /// The inverted address and inverted command bytes are automatically generated.
  factory NecEncoder.standard({
    required int address,
    required int command,
    int frequency = 38000,
    String name = 'NEC Standard',
  }) {
    final addr = address & 0xFF;
    final invAddr = (~addr) & 0xFF;
    final cmd = command & 0xFF;
    final invCmd = (~cmd) & 0xFF;

    return NecEncoder.rawBytes(
      bytes: [addr, invAddr, cmd, invCmd],
      frequency: frequency,
      name: name,
    );
  }

  /// Creates an extended NEC packet with 16-bit address and 8-bit command.
  /// Commonly used by Samsung, LG, Pioneer, etc.
  factory NecEncoder.extended({
    required int address16,
    required int command,
    int frequency = 38000,
    String name = 'NEC Extended',
  }) {
    final addrLow = address16 & 0xFF;
    final addrHigh = (address16 >> 8) & 0xFF;
    final cmd = command & 0xFF;
    final invCmd = (~cmd) & 0xFF;

    return NecEncoder.rawBytes(
      bytes: [addrLow, addrHigh, cmd, invCmd],
      frequency: frequency,
      name: name,
    );
  }

  /// Preset for LG TV Power toggle (Address: 0x04, Command: 0x08).
  factory NecEncoder.lgTvPower() {
    return NecEncoder.standard(
      address: 0x04,
      command: 0x08,
      name: 'LG TV Power',
    );
  }

  final List<int> bytes;
  final int frequency;
  final String name;

  static const int headerMark = 9000;
  static const int headerSpace = 4500;
  static const int bitMark = 560;
  static const int zeroSpace = 560;
  static const int oneSpace = 1690;
  static const int stopMark = 560;

  static const BitTiming bitTiming = BitTiming.pulseDistance(
    mark: bitMark,
    oneSpace: oneSpace,
    zeroSpace: zeroSpace,
  );

  @override
  IrPacket encode() {
    final train = PulseTrain()
      // 1. Leader code
      ..mark(headerMark)
      ..space(headerSpace)
      // 2. Data bits (32 bits, transmitted LSB first per byte)
      ..bytes(bytes, bitTiming)
      // 3. Stop bit
      ..mark(stopMark);

    return IrPacket(
      frequency: frequency,
      pattern: train.build(),
      name: name,
    );
  }
}
