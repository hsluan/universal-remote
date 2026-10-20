import '../models/ir_packet.dart';

/// Strategy interface for IR protocol encoders.
abstract class IrProtocolEncoder {
  /// Encodes a protocol-specific command into an [IrPacket].
  IrPacket encode();
}
