import 'package:flutter/services.dart';
import '../../domain/models/carrier_frequency_range.dart';
import '../../domain/models/ir_packet.dart';
import '../../domain/services/ir_transmitter.dart';

/// Service interfacing with the native Android ConsumerIrManager via MethodChannel.
class ConsumerIrService implements IrTransmitter {
  ConsumerIrService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('universal_remote/ir');

  final MethodChannel _channel;

  /// Checks if the device has a built-in Consumer IR emitter.
  @override
  Future<bool> hasIrEmitter() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasIrEmitter');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException {
      // Graceful fallback when running in tests or unsupported environments
      return false;
    }
  }

  /// Retrieves the carrier frequency ranges supported by the IR transmitter.
  @override
  Future<List<CarrierFrequencyRange>> getCarrierFrequencies() async {
    try {
      final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getCarrierFrequencies');
      if (result == null) return [];
      return result.map((m) => CarrierFrequencyRange.fromMap(m)).toList();
    } on PlatformException catch (_) {
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  /// Transmits an alternating mark/space pattern at the specified carrier frequency.
  @override
  Future<void> transmit(IrPacket packet) async {
    await _channel.invokeMethod<bool>('transmit', {
      'frequency': packet.frequency,
      'pattern': packet.pattern,
    });
  }
}
