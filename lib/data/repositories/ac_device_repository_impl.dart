import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/ac_device.dart';
import '../../domain/repositories/ac_device_repository.dart';

/// Stores paired ACs as one JSON list in shared preferences.
///
/// Operations run one after another, so a read-modify-write never works on a
/// list another write is about to replace.
class AcDeviceRepositoryImpl implements AcDeviceRepository {
  AcDeviceRepositoryImpl({required this.preferences});

  static const String storageKey = 'ac_devices.v1';

  final Future<SharedPreferences> preferences;
  List<AcDevice>? _cache;
  Future<void> _tail = Future<void>.value();

  @override
  Future<List<AcDevice>> getAll() => _serialized(() async => List<AcDevice>.unmodifiable(await _load()));

  @override
  Future<void> save(AcDevice device) => _serialized(() async {
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
  Future<AcDevice?> update(String id, AcDevice Function(AcDevice current) change) => _serialized(() async {
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

  Future<List<AcDevice>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = (await preferences).getString(storageKey);
    final devices = <AcDevice>[];
    if (raw != null) {
      for (final entry in jsonDecode(raw) as List<dynamic>) {
        try {
          devices.add(AcDevice.fromJson(entry as Map<String, dynamic>));
        } on Object {
          // Skip a corrupt entry instead of losing every device.
          continue;
        }
      }
    }
    return _cache = devices;
  }

  Future<void> _store(List<AcDevice> devices) async {
    _cache = devices;
    await (await preferences).setString(storageKey, jsonEncode([for (final d in devices) d.toJson()]));
  }
}
