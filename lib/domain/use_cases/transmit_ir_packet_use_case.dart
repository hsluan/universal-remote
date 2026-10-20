import '../models/ir_packet.dart';
import '../services/ir_transmitter.dart';

class TransmitIrPacketUseCase {
  const TransmitIrPacketUseCase({required this.transmitter});

  final IrTransmitter transmitter;

  /// Android's `ConsumerIrManager.transmit` rejects patterns longer than 2 seconds.
  static const int maxPatternDurationMicros = 2000000;

  Future<void> execute(IrPacket packet) async {
    if (packet.pattern.isEmpty) {
      throw ArgumentError.value(packet, 'packet', 'IR pattern is empty');
    }
    if (packet.totalDurationMicros > maxPatternDurationMicros) {
      throw ArgumentError.value(
        packet,
        'packet',
        'IR pattern lasts ${packet.totalDurationMicros} us, above the $maxPatternDurationMicros us platform limit',
      );
    }
    await transmitter.transmit(packet);
  }
}
