import '../../../domain/devices/device_kind.dart';

/// One recommendation in a setup guide.
class GuidePoint {
  const GuidePoint({required this.title, required this.detail, this.tag});

  final String title;
  final String detail;

  /// Short label such as "Works now" or "Coming next".
  final String? tag;
}

/// What to buy or set up so the app can control a kind of device.
class SetupGuide {
  const SetupGuide({required this.intro, required this.points});

  final String intro;
  final List<GuidePoint> points;
}

/// Guides for kinds that usually need add-on hardware or a not-yet-built integration.
const Map<DeviceKind, SetupGuide> setupGuides = {};
