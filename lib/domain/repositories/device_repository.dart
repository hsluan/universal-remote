import '../devices/device.dart';

/// Every paired device, of any kind.
abstract interface class DeviceRepository {
  Future<List<Device>> getAll();

  /// Inserts or replaces the device with the same id.
  Future<void> save(Device device);

  /// Applies [change] to the stored device with [id] and saves the result.
  ///
  /// Use it for partial updates (last state, name): it always starts from the stored
  /// value, so writers changing different fields never undo each other. Returns the
  /// updated device, or `null` when no device has that id.
  Future<Device?> update(String id, Device Function(Device current) change);

  Future<void> delete(String id);
}
