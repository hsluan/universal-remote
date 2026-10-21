import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/cameras/camera_credentials.dart';

/// [CredentialStore] in the Android Keystore-backed secure storage (AES-GCM data,
/// RSA-OAEP key wrapping: the plugin's defaults since version 10).
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(String deviceId) => 'camera_credentials.$deviceId';

  @override
  Future<CameraCredentials?> read(String deviceId) async {
    final raw = await _storage.read(key: _key(deviceId));
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CameraCredentials(user: json['user'] as String? ?? '', password: json['password'] as String? ?? '');
  }

  @override
  Future<void> write(String deviceId, CameraCredentials credentials) {
    return _storage.write(
      key: _key(deviceId),
      value: jsonEncode({'user': credentials.user, 'password': credentials.password}),
    );
  }

  @override
  Future<void> delete(String deviceId) => _storage.delete(key: _key(deviceId));
}
