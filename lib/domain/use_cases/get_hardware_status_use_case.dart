import '../models/carrier_frequency_range.dart';
import '../services/ir_transmitter.dart';

class HardwareStatus {
  const HardwareStatus({
    required this.hasEmitter,
    required this.frequencies,
  });

  final bool hasEmitter;
  final List<CarrierFrequencyRange> frequencies;
}

class GetHardwareStatusUseCase {
  const GetHardwareStatusUseCase({required this.transmitter});

  final IrTransmitter transmitter;

  Future<HardwareStatus> execute() async {
    final hasEmitter = await transmitter.hasIrEmitter();
    final frequencies = hasEmitter ? await transmitter.getCarrierFrequencies() : <CarrierFrequencyRange>[];
    return HardwareStatus(hasEmitter: hasEmitter, frequencies: frequencies);
  }
}
