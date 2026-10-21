import '../devices/device.dart';
import 'camera_brand.dart';
import 'camera_credentials.dart';

/// A camera streamed over the home Wi-Fi with RTSP: the typed view of a [Device]
/// whose connection is a [LanConnection] with protocol [protocol].
class IpCamera {
  const IpCamera({
    required this.deviceId,
    required this.name,
    required this.brand,
    required this.host,
    required this.mainPath,
    this.subPath,
    this.rtspPort = CameraBrand.rtspPort,
    int? onvifPort,
    this.ptz = false,
    this.room,
  }) : onvifPort = onvifPort ?? 80;

  /// Views [device] as an IP camera; throws [ArgumentError] unless [isIpCamera] holds.
  factory IpCamera.fromDevice(Device device) {
    final connection = device.connection;
    if (!isIpCamera(device) || connection is! LanConnection) {
      throw ArgumentError.value(device.id, 'device', 'is not an RTSP camera');
    }
    final options = connection.options;
    final brand = CameraBrand.fromId(options[_brandKey]) ?? CameraBrand.other;
    return IpCamera(
      deviceId: device.id,
      name: device.name,
      brand: brand,
      host: connection.host,
      rtspPort: connection.port ?? CameraBrand.rtspPort,
      mainPath: options[_mainKey] ?? '/',
      subPath: options[_subKey],
      onvifPort: int.tryParse(options[_onvifPortKey] ?? '') ?? brand.onvifPort,
      ptz: options[_ptzKey] == '1',
      room: device.room,
    );
  }

  static const String protocol = 'rtsp';

  static const String _brandKey = 'brand';
  static const String _mainKey = 'main';
  static const String _subKey = 'sub';
  static const String _onvifPortKey = 'onvifPort';
  static const String _ptzKey = 'ptz';

  static bool isIpCamera(Device device) {
    final connection = device.connection;
    return device.kind == DeviceKind.camera && connection is LanConnection && connection.protocol == protocol;
  }

  final String deviceId;
  final String name;
  final CameraBrand brand;
  final String host;
  final int rtspPort;

  /// Path (and query) of the full-resolution stream, e.g. `/stream1`.
  final String mainPath;

  /// Path of the small stream, when the camera has one.
  final String? subPath;

  final int onvifPort;

  /// Whether the camera answered ONVIF pan/tilt when it was added.
  final bool ptz;

  final String? room;

  Device toDevice() => Device(
        id: deviceId,
        name: name,
        kind: DeviceKind.camera,
        brandName: brand == CameraBrand.other ? '' : brand.label,
        room: room,
        connection: LanConnection(
          protocol: protocol,
          host: host,
          port: rtspPort,
          options: {
            _brandKey: brand.id,
            _mainKey: mainPath,
            _subKey: ?subPath,
            _onvifPortKey: '$onvifPort',
            _ptzKey: ptz ? '1' : '0',
          },
        ),
      );

  /// The stream address with [credentials] in it, as players expect.
  ///
  /// [preferSub] picks the small stream when the camera has one: the Redmi 4X
  /// decodes only one 1080p video at a time in hardware.
  Uri streamUri(CameraCredentials? credentials, {bool preferSub = true}) =>
      rtspUri(host: host, port: rtspPort, path: preferSub && subPath != null ? subPath! : mainPath, credentials: credentials);
}

/// Builds `rtsp://user:password@host:port/path?query`, percent-encoding the user
/// and password so characters such as `@` or `:` cannot break the address.
Uri rtspUri({required String host, required int port, required String path, CameraCredentials? credentials}) {
  final queryStart = path.indexOf('?');
  final user = credentials == null || credentials.user.isEmpty
      ? null
      : '${Uri.encodeComponent(credentials.user)}:${Uri.encodeComponent(credentials.password)}';
  return Uri(
    scheme: 'rtsp',
    userInfo: user,
    host: host,
    port: port,
    path: queryStart < 0 ? path : path.substring(0, queryStart),
    query: queryStart < 0 ? null : path.substring(queryStart + 1),
  );
}
