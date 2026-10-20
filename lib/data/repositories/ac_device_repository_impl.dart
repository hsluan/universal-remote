import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/ac_device.dart';
import '../../domain/repositories/ac_device_repository.dart';

/// Stores paired ACs as one JSON list in shared preferences.
class AcDeviceRepositoryImpl implements AcDeviceRepository {
  AcDeviceRepositoryImpl({required this.preferences});

  static const String storageKey = 'ac_devices.v1';

  final Future<SharedPreferences> preferences;
  List<AcDevice>? _cache;

  @override
  Future<List<AcDevice>> getAll() async {
    return List.unmodifiable(await _load());
  }

  @override
  Future<void> save(AcDevice device) async {
    final devices = [...await _load()];
    final index = devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.add(device);
    }
    await _store(devices);
  }

  @override
  Future<void> delete(String id) async {
    final devices = [...await _load()]..removeWhere((d) => d.id == id);
    await _store(devices);
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
