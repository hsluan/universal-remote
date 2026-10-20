/// Command protocols the app can synthesize from a device/function number.
enum IrProtocol {
  /// NEC1 (9 ms leader). Without a subdevice the address byte is followed by its inverse.
  nec('nec'),

  /// Samsung32 / NECx (4.5 ms leader).
  samsung('samsung'),

  sony12('sony12'),
  sony15('sony15'),
  sony20('sony20'),

  /// Panasonic 48-bit Kaseikyo.
  panasonic('panasonic');

  const IrProtocol(this.id);

  /// Identifier used in the bundled JSON database.
  final String id;

  static IrProtocol? fromId(String id) {
    for (final protocol in values) {
      if (protocol.id == id) return protocol;
    }
    return null;
  }
}

/// One stored remote button: either protocol parameters or a raw Pronto code.
sealed class IrCode {
  const IrCode();
}

/// A code synthesized by a protocol encoder, using IRDB's device/subdevice/function numbering.
final class ProtocolIrCode extends IrCode {
  const ProtocolIrCode({
    required this.protocol,
    required this.device,
    this.subdevice,
    required this.function,
  });

  final IrProtocol protocol;
  final int device;

  /// Second address byte; `null` means the protocol default (e.g. NEC's inverted device).
  final int? subdevice;

  final int function;

  @override
  bool operator ==(Object other) =>
      other is ProtocolIrCode &&
      other.protocol == protocol &&
      other.device == device &&
      other.subdevice == subdevice &&
      other.function == function;

  @override
  int get hashCode => Object.hash(protocol, device, subdevice, function);

  @override
  String toString() => '${protocol.id}($device.${subdevice ?? '-'}:$function)';
}

/// A learned code stored as Pronto hex.
final class ProntoIrCode extends IrCode {
  const ProntoIrCode(this.hex);

  final String hex;

  @override
  bool operator ==(Object other) => other is ProntoIrCode && other.hex == hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => 'pronto(${hex.length > 24 ? '${hex.substring(0, 24)}...' : hex})';
}
