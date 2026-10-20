import '../models/ac_device.dart';

abstract interface class AcDeviceRepository {
  Future<List<AcDevice>> getAll();

  /// Inserts or replaces the device with the same id.
  Future<void> save(AcDevice device);

  /// Applies [change] to the stored device with [id] and saves the result.
  ///
  /// Use it for partial updates (last state, name): it always starts from the stored
  /// value, so writers changing different fields never undo each other. Returns the
  /// updated device, or `null` when no device has that id.
  Future<AcDevice?> update(String id, AcDevice Function(AcDevice current) change);

  Future<void> delete(String id);
}
