import '../models/carrier_frequency_range.dart';
import '../models/ir_packet.dart';

/// Port to the IR emitter hardware.
///
/// The domain layer depends on this interface; the data layer adapts the
/// platform (Android `ConsumerIrManager`) behind it.
abstract interface class IrTransmitter {
  /// Whether the device has a usable consumer IR emitter.
  Future<bool> hasIrEmitter();

  /// Carrier frequency ranges the emitter can modulate.
  Future<List<CarrierFrequencyRange>> getCarrierFrequencies();

  /// Emits [packet] once.
  Future<void> transmit(IrPacket packet);
}
