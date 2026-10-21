import 'camera_credentials.dart';

/// Outcome of asking a camera to describe one stream.
sealed class RtspProbeResult {
  const RtspProbeResult();
}

/// The stream exists and the login was accepted.
final class RtspStreamFound extends RtspProbeResult {
  const RtspStreamFound({this.videoCodec});

  /// From the stream description, e.g. `H264` or `H265`; `null` when not announced.
  final String? videoCodec;
}

/// The camera refused the user or password.
final class RtspUnauthorized extends RtspProbeResult {
  const RtspUnauthorized();
}

/// The camera answered, but not for this path (another path may work).
final class RtspNotFound extends RtspProbeResult {
  const RtspNotFound(this.status);

  final int status;
}

/// Nothing answered at that address and port.
final class RtspUnreachable extends RtspProbeResult {
  const RtspUnreachable(this.reason);

  final String reason;
}

/// Checks a stream without playing it (RTSP DESCRIBE), so adding a camera can tell
/// a wrong password from a wrong address or path.
abstract interface class RtspProber {
  Future<RtspProbeResult> describe(Uri streamUri, CameraCredentials? credentials);
}

/// A camera that answered an ONVIF search on the home network.
class DiscoveredCamera {
  const DiscoveredCamera({required this.host, required this.onvifPort, this.name, this.hardware});

  final String host;
  final int onvifPort;

  /// From the camera's ONVIF scopes, e.g. "TP-IPC" and "C200".
  final String? name;
  final String? hardware;

  String get label => [?hardware, ?name].join(' · ');

  @override
  bool operator ==(Object other) => other is DiscoveredCamera && other.host == host && other.onvifPort == onvifPort;

  @override
  int get hashCode => Object.hash(host, onvifPort);
}

/// Finds ONVIF cameras on the home network (WS-Discovery).
abstract interface class CameraDiscovery {
  Stream<DiscoveredCamera> discover({Duration timeout});
}

/// Pan/tilt directions; each component is -1, 0 or 1.
enum PtzDirection {
  up(0, 1),
  down(0, -1),
  left(-1, 0),
  right(1, 0);

  const PtzDirection(this.pan, this.tilt);

  final int pan;
  final int tilt;
}

/// Pan/tilt of one camera over ONVIF.
abstract interface class PtzControl {
  /// Whether the camera exposes ONVIF pan/tilt for this login.
  Future<bool> isSupported();

  /// Starts moving at half speed; the camera keeps moving until [stop].
  Future<void> move(PtzDirection direction);

  Future<void> stop();
}

/// Creates the ONVIF client of one camera.
typedef PtzControlFactory = PtzControl Function({
  required String host,
  required int port,
  required CameraCredentials credentials,
});
