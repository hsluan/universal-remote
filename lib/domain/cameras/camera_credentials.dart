/// A camera's RTSP / ONVIF login.
class CameraCredentials {
  const CameraCredentials({required this.user, required this.password});

  final String user;
  final String password;

  @override
  bool operator ==(Object other) => other is CameraCredentials && other.user == user && other.password == password;

  @override
  int get hashCode => Object.hash(user, password);

  /// Never prints the password.
  @override
  String toString() => 'CameraCredentials($user, ***)';
}

/// Keeps camera logins outside the device list, in the platform's secure storage.
abstract interface class CredentialStore {
  Future<CameraCredentials?> read(String deviceId);

  Future<void> write(String deviceId, CameraCredentials credentials);

  Future<void> delete(String deviceId);
}
