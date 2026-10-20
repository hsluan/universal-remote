import '../models/ac_device.dart';

abstract interface class AcDeviceRepository {
  Future<List<AcDevice>> getAll();

  /// Inserts or replaces the device with the same id.
  Future<void> save(AcDevice device);

  Future<void> delete(String id);
}
