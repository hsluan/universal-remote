/// How the app reaches a device. Each connection type is served by one integration
/// (IR codes, a LAN protocol, a Bluetooth protocol, or the maker's own app).
sealed class DeviceConnection {
  const DeviceConnection();

  Map<String, Object?> toJson();

  /// Reads a connection written by [toJson]. A type this version doesn't know
  /// comes back as [UnknownConnection], so it is kept rather than dropped.
  static DeviceConnection fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'ir':
        return IrConnection(codeId: json['code'] as String);
      case 'lan':
        return LanConnection(
          protocol: json['protocol'] as String,
          host: json['host'] as String,
          port: (json['port'] as num?)?.toInt(),
          deviceId: json['deviceId'] as String?,
        );
      case 'ble':
        return BleConnection(protocol: json['protocol'] as String, address: json['address'] as String);
      case 'app':
        return AppLinkConnection(packageName: json['package'] as String, appName: json['appName'] as String);
      default:
        return UnknownConnection(Map<String, Object?>.from(json));
    }
  }
}

/// Infrared from the phone's blaster. One-way: the app keeps the state it last sent.
final class IrConnection extends DeviceConnection {
  const IrConnection({required this.codeId});

  /// The IR code (encoder id) found during pairing.
  final String codeId;

  @override
  Map<String, Object?> toJson() => {'type': 'ir', 'code': codeId};

  @override
  bool operator ==(Object other) => other is IrConnection && other.codeId == codeId;

  @override
  int get hashCode => codeId.hashCode;
}

/// A device on the home Wi-Fi, controlled with its local protocol (no vendor cloud).
final class LanConnection extends DeviceConnection {
  const LanConnection({required this.protocol, required this.host, this.port, this.deviceId});

  /// Protocol id, e.g. `shelly`, `wiz`, `yeelight`, `onvif`.
  final String protocol;
  final String host;
  final int? port;

  /// The device's own id (MAC, serial), to find it again when its address changes.
  final String? deviceId;

  @override
  Map<String, Object?> toJson() => {
        'type': 'lan',
        'protocol': protocol,
        'host': host,
        if (port != null) 'port': port,
        if (deviceId != null) 'deviceId': deviceId,
      };

  @override
  bool operator ==(Object other) =>
      other is LanConnection &&
      other.protocol == protocol &&
      other.host == host &&
      other.port == port &&
      other.deviceId == deviceId;

  @override
  int get hashCode => Object.hash(protocol, host, port, deviceId);
}

/// A Bluetooth Low Energy device near the phone.
final class BleConnection extends DeviceConnection {
  const BleConnection({required this.protocol, required this.address});

  /// Protocol id, e.g. `itag`.
  final String protocol;
  final String address;

  @override
  Map<String, Object?> toJson() => {'type': 'ble', 'protocol': protocol, 'address': address};

  @override
  bool operator ==(Object other) => other is BleConnection && other.protocol == protocol && other.address == address;

  @override
  int get hashCode => Object.hash(protocol, address);
}

/// A shortcut to the maker's app, for devices that only their own app can reach
/// (Xiaomi cameras, Bluetooth smart keys, cloud-only devices).
final class AppLinkConnection extends DeviceConnection {
  const AppLinkConnection({required this.packageName, required this.appName});

  /// Android package, e.g. `com.xiaomi.smarthome`.
  final String packageName;
  final String appName;

  @override
  Map<String, Object?> toJson() => {'type': 'app', 'package': packageName, 'appName': appName};

  @override
  bool operator ==(Object other) =>
      other is AppLinkConnection && other.packageName == packageName && other.appName == appName;

  @override
  int get hashCode => Object.hash(packageName, appName);
}

/// A connection type written by a newer version of the app.
final class UnknownConnection extends DeviceConnection {
  const UnknownConnection(this.json);

  final Map<String, Object?> json;

  @override
  Map<String, Object?> toJson() => json;
}
