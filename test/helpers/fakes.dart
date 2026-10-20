import 'package:flutter/services.dart';
import 'package:universal_remote/domain/models/ac_brand.dart';
import 'package:universal_remote/domain/models/ac_device.dart';
import 'package:universal_remote/domain/models/carrier_frequency_range.dart';
import 'package:universal_remote/domain/models/ir_packet.dart';
import 'package:universal_remote/domain/repositories/ac_brand_repository.dart';
import 'package:universal_remote/domain/repositories/ac_device_repository.dart';
import 'package:universal_remote/domain/services/ir_transmitter.dart';

/// Records every packet instead of emitting it.
class FakeTransmitter implements IrTransmitter {
  FakeTransmitter({this.hasEmitter = true});

  bool hasEmitter;

  /// When set, [transmit] throws this platform error.
  String? failWithCode;

  /// Runs inside every [transmit] before it completes: await something to keep the
  /// send in flight, or throw to make this one transmission fail.
  Future<void> Function(IrPacket packet)? onTransmit;

  /// Packets that went out, in order.
  final List<IrPacket> sent = [];

  int _inFlight = 0;

  /// Most transmissions ever in flight at the same time.
  int maxInFlight = 0;

  @override
  Future<bool> hasIrEmitter() async => hasEmitter;

  @override
  Future<List<CarrierFrequencyRange>> getCarrierFrequencies() async =>
      hasEmitter ? const [CarrierFrequencyRange(minFrequency: 30000, maxFrequency: 60000)] : const [];

  @override
  Future<void> transmit(IrPacket packet) async {
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      final hook = onTransmit;
      if (hook != null) await hook(packet);
      final code = failWithCode;
      if (code != null) throw PlatformException(code: code);
      sent.add(packet);
    } finally {
      _inFlight--;
    }
  }
}

class InMemoryAcDeviceRepository implements AcDeviceRepository {
  InMemoryAcDeviceRepository([List<AcDevice> initial = const []]) : devices = [...initial];

  final List<AcDevice> devices;

  @override
  Future<List<AcDevice>> getAll() async => List.unmodifiable(devices);

  @override
  Future<void> save(AcDevice device) async {
    final index = devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.add(device);
    }
  }

  @override
  Future<AcDevice?> update(String id, AcDevice Function(AcDevice current) change) async {
    final index = devices.indexWhere((d) => d.id == id);
    if (index < 0) return null;
    return devices[index] = change(devices[index]);
  }

  @override
  Future<void> delete(String id) async => devices.removeWhere((d) => d.id == id);
}

class FakeAcBrandRepository implements AcBrandRepository {
  FakeAcBrandRepository([this.brands = defaultBrands]);

  static const List<AcBrand> defaultBrands = [
    AcBrand(id: 'casper', name: 'Casper', codeIds: [], rank: 3),
    AcBrand(id: 'daikin', name: 'Daikin', codeIds: ['daikin'], rank: 1),
    AcBrand(id: 'gree', name: 'Gree', codeIds: ['gree_yaw1f', 'gree_ybofb'], rank: 2),
    AcBrand(id: 'sharp', name: 'Sharp', codeIds: []),
  ];

  final List<AcBrand> brands;

  @override
  Future<List<AcBrand>> getBrands() async => brands;
}
