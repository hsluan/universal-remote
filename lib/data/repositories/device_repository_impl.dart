import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/devices/device.dart';
import '../../domain/models/ac_device.dart';
import '../../domain/repositories/device_repository.dart';

/// Stores every device as one JSON list in shared preferences.
///
/// Operations run one after another, so a read-modify-write never works on a
/// list another write is about to replace.
class DeviceRepositoryImpl implements DeviceRepository {
  DeviceRepositoryImpl({required this.preferences});

  static const String storageKey = 'devices.v2';

  /// Version 1 stored only IR air conditioners. It is read once to migrate and
  /// left in place, so installing an older build still finds its ACs.
  static const String legacyAcKey = 'ac_devices.v1';

  final Future<SharedPreferences> preferences;
  List<Device>? _cache;
  Future<void> _tail = Future<void>.value();

  @override
  Future<List<Device>> getAll() => _serialized(() async => List<Device>.unmodifiable(await _load()));

  @override
  Future<void> save(Device device) => _serialized(() async {
        final devices = [...await _load()];
        final index = devices.indexWhere((d) => d.id == device.id);
        if (index >= 0) {
          devices[index] = device;
        } else {
          devices.add(device);
        }
        await _store(devices);
      });

  @override
  Future<Device?> update(String id, Device Function(Device current) change) => _serialized(() async {
        final devices = [...await _load()];
        final index = devices.indexWhere((d) => d.id == id);
        if (index < 0) return null;
        final updated = change(devices[index]);
        devices[index] = updated;
        await _store(devices);
        return updated;
      });

  @override
  Future<void> delete(String id) => _serialized(() async {
        final devices = [...await _load()]..removeWhere((d) => d.id == id);
        await _store(devices);
      });

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    // A failed operation must not block the ones queued after it.
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<List<Device>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final prefs = await preferences;
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      final migrated = _decodeLegacy(prefs.getString(legacyAcKey));
      _cache = migrated;
      if (migrated.isNotEmpty) await _store(migrated);
      return migrated;
    }
    return _cache = _decode(raw, Device.fromJson);
  }

  static List<Device> _decodeLegacy(String? raw) =>
      raw == null ? [] : _decode(raw, (json) => AcDevice.fromLegacyJson(json).toDevice());

  static List<Device> _decode(String raw, Device Function(Map<String, dynamic>) read) {
    final devices = <Device>[];
    for (final entry in jsonDecode(raw) as List<dynamic>) {
      try {
        devices.add(read(entry as Map<String, dynamic>));
      } on Object {
        // Skip a corrupt or unknown entry instead of losing every device.
        continue;
      }
    }
    return devices;
  }

  Future<void> _store(List<Device> devices) async {
    _cache = devices;
    await (await preferences).setString(storageKey, jsonEncode([for (final d in devices) d.toJson()]));
  }
}
