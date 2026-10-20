import '../models/ir_packet.dart';
import '../models/ir_send_record.dart';
import '../services/ir_send_log.dart';
import '../services/ir_transmitter.dart';

/// Emits one packet; every attempt, sent or failed, is recorded in [log].
class TransmitIrPacketUseCase {
  const TransmitIrPacketUseCase({required this.transmitter, this.log});

  final IrTransmitter transmitter;
  final IrSendLog? log;

  /// Android's `ConsumerIrManager.transmit` rejects patterns longer than 2 seconds.
  static const int maxPatternDurationMicros = 2000000;

  /// [source] and [description] label the log entry; [frameHex] is the protocol frame, when known.
  Future<void> execute(
    IrPacket packet, {
    String source = 'IR',
    String? description,
    String? frameHex,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      _validate(packet);
      await transmitter.transmit(packet);
      _record(packet, source, description, frameHex, stopwatch.elapsed, null);
    } catch (e) {
      _record(packet, source, description, frameHex, stopwatch.elapsed, e);
      rethrow;
    }
  }

  static void _validate(IrPacket packet) {
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
  }

  void _record(IrPacket packet, String source, String? description, String? frameHex, Duration elapsed, Object? error) {
    log?.add(IrSendRecord(
      time: DateTime.now(),
      source: source,
      description: description ?? packet.name,
      frameHex: frameHex,
      frequency: packet.frequency,
      pulses: packet.pattern.length,
      patternMicros: packet.totalDurationMicros,
      elapsed: elapsed,
      error: error?.toString(),
    ));
  }
}
