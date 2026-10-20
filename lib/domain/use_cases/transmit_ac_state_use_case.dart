import '../encoders/ac/ac_protocol_encoder.dart';
import '../models/ac_state.dart';
import '../models/ir_packet.dart';
import 'transmit_ir_packet_use_case.dart';

/// Encodes a full AC state with a code and emits it.
///
/// Sends to a paired AC go through `AcSendQueue`, which serializes them and
/// tracks the state the AC last received; this use case is the single step below it.
class TransmitAcStateUseCase {
  const TransmitAcStateUseCase({required this.transmitPacket});

  final TransmitIrPacketUseCase transmitPacket;

  /// [previous] is the last state the AC received, if known (toggle commands are
  /// derived from it). [source] labels the send log entry. Returns the packet sent.
  Future<IrPacket> execute(
    AcProtocolEncoder encoder,
    AcState state, {
    AcState? previous,
    String source = 'AC',
  }) async {
    final caps = encoder.capabilities;
    final target = caps.normalize(state);
    final packet = encoder.encode(target, previous: previous == null ? null : caps.normalize(previous));
    await transmitPacket.execute(
      packet,
      source: source,
      description: '${packet.name} · $target',
      frameHex: encoder is AcFrameEncoder ? hexBytes(encoder.buildFrame(target)) : null,
    );
    return packet;
  }
}
