import '../encoders/ac/ac_encoder_registry.dart';
import '../encoders/ac/ac_protocol_encoder.dart';
import '../models/ac_state.dart';
import '../models/ir_packet.dart';
import 'transmit_ir_packet_use_case.dart';

/// Encodes a full AC state with the device's code and emits it.
class TransmitAcStateUseCase {
  const TransmitAcStateUseCase({required this.registry, required this.transmitPacket});

  final AcEncoderRegistry registry;
  final TransmitIrPacketUseCase transmitPacket;

  /// Returns the packet that was sent (for logs and diagnostics).
  /// [previous] is the last state sent to the device, if known.
  Future<IrPacket> execute(String codeId, AcState state, {AcState? previous}) {
    return executeWith(registry.require(codeId), state, previous: previous);
  }

  Future<IrPacket> executeWith(AcProtocolEncoder encoder, AcState state, {AcState? previous}) async {
    final caps = encoder.capabilities;
    final packet = encoder.encode(
      caps.normalize(state),
      previous: previous == null ? null : caps.normalize(previous),
    );
    await transmitPacket.execute(packet);
    return packet;
  }
}
