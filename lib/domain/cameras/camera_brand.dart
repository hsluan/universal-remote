/// IP camera makers the app streams locally, with their RTSP conventions.
///
/// Researched 2026-10-21 (sources in ARCHITECTURE_AND_PLAN.md). Paths are tried in
/// order while testing the connection; the first one the camera accepts is kept.
enum CameraBrand {
  imou(
    id: 'imou',
    label: 'Imou',
    defaultUser: 'admin',
    mainPaths: ['/cam/realmonitor?channel=1&subtype=0'],
    subPaths: ['/cam/realmonitor?channel=1&subtype=1'],
    onvifPort: 80,
    appPackage: 'com.mm.android.smartlifeiot',
    passwordHint: 'The safety code on the camera label, or the device password set in Imou Life.',
  ),
  ezviz(
    id: 'ezviz',
    label: 'EZVIZ',
    defaultUser: 'admin',
    mainPaths: ['/ch1/main', '/Streaming/Channels/101'],
    subPaths: ['/Streaming/Channels/102'],
    onvifPort: 80,
    appPackage: 'com.ezviz',
    passwordHint: 'The 6-letter verification code on the camera label. Enable RTSP first: EZVIZ app › Profile › '
        'Settings › LAN Live View › your camera › Local Server Settings.',
  ),
  tapo(
    id: 'tapo',
    label: 'Tapo',
    defaultUser: '',
    mainPaths: ['/stream1'],
    subPaths: ['/stream2'],
    onvifPort: 2020,
    appPackage: 'com.tplink.iot',
    passwordHint: 'The Camera Account created in the Tapo app: your camera › Device Settings › Advanced Settings › '
        'Camera Account (not your TP-Link login).',
  ),
  hikvision(
    id: 'hikvision',
    label: 'Hikvision',
    defaultUser: 'admin',
    mainPaths: ['/Streaming/Channels/101'],
    subPaths: ['/Streaming/Channels/102'],
    onvifPort: 80,
    appPackage: 'com.connect.enduser',
    passwordHint: "The camera's own user. For pan/tilt, enable ONVIF in its web page (Configuration › Network › "
        'Advanced Settings › Integration Protocol) and use the ONVIF user.',
  ),
  other(
    id: 'other',
    label: 'Other RTSP / ONVIF camera',
    defaultUser: 'admin',
    mainPaths: [],
    subPaths: [],
    onvifPort: 80,
    passwordHint: "The camera's RTSP user and password, from its manual.",
  );

  const CameraBrand({
    required this.id,
    required this.label,
    required this.defaultUser,
    required this.mainPaths,
    required this.subPaths,
    required this.onvifPort,
    required this.passwordHint,
    this.appPackage,
  });

  /// Persisted in the device's connection options.
  final String id;
  final String label;

  /// Prefilled user name (empty when the user picks it, as with Tapo).
  final String defaultUser;

  /// Candidate paths for the full-resolution and the small stream.
  final List<String> mainPaths;
  final List<String> subPaths;

  final int onvifPort;

  /// The maker's app, for what this app does not do (recordings, settings).
  final String? appPackage;

  /// Where to find the user and password for this brand.
  final String passwordHint;

  static const int rtspPort = 554;

  static CameraBrand? fromId(String? id) {
    for (final brand in values) {
      if (brand.id == id) return brand;
    }
    return null;
  }
}
