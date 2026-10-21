import 'package:flutter/services.dart';
import 'package:universal_remote/domain/models/ac_brand.dart';
import 'package:universal_remote/domain/devices/device.dart';
import 'package:universal_remote/domain/models/carrier_frequency_range.dart';
import 'package:universal_remote/domain/models/ir_packet.dart';
import 'package:universal_remote/domain/repositories/ac_brand_repository.dart';
import 'package:universal_remote/domain/repositories/device_repository.dart';
import 'package:universal_remote/domain/services/app_launcher.dart';
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

class InMemoryDeviceRepository implements DeviceRepository {
  InMemoryDeviceRepository([List<Device> initial = const []]) : devices = [...initial];

  final List<Device> devices;

  @override
  Future<List<Device>> getAll() async => List.unmodifiable(devices);

  @override
  Future<void> save(Device device) async {
    final index = devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.add(device);
    }
  }

  @override
  Future<Device?> update(String id, Device Function(Device current) change) async {
    final index = devices.indexWhere((d) => d.id == id);
    if (index < 0) return null;
    return devices[index] = change(devices[index]);
  }

  @override
  Future<void> delete(String id) async => devices.removeWhere((d) => d.id == id);
}

/// Pretends the packages in [installed] are installed; records what was opened.
class FakeAppLauncher implements AppLauncher {
  FakeAppLauncher({Set<String>? installed}) : installed = installed ?? {};

  final Set<String> installed;
  final List<String> launched = [];
  final List<String> storePages = [];

  @override
  Future<bool> isInstalled(String packageName) async => installed.contains(packageName);

  @override
  Future<bool> launch(String packageName) async {
    if (!installed.contains(packageName)) return false;
    launched.add(packageName);
    return true;
  }

  @override
  Future<void> openStorePage(String packageName) async => storePages.add(packageName);
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
