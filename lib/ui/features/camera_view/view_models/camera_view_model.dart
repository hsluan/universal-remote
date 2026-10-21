import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../domain/cameras/camera_credentials.dart';
import '../../../../domain/cameras/camera_services.dart';
import '../../../../domain/cameras/ip_camera.dart';
import '../../../core/video/live_video_player.dart';

/// Live view of one IP camera: plays the small stream by default (one 1080p
/// hardware decoder on the Redmi 4X), switches to the full one on demand, and
/// pans/tilts over ONVIF while a direction is held.
class CameraViewModel extends ChangeNotifier {
  CameraViewModel({
    required this.camera,
    required this.credentials,
    required this.player,
    required this.createPtz,
  }) {
    player.state.addListener(notifyListeners);
  }

  final IpCamera camera;
  final CredentialStore credentials;
  final LiveVideoPlayer player;
  final PtzControlFactory createPtz;

  CameraCredentials? _login;
  PtzControl? _ptz;

  bool _highQuality = false;

  /// Whether the full-resolution stream is playing (instead of the small one).
  bool get highQuality => _highQuality;

  bool get hasSubStream => camera.subPath != null;

  bool get canPan => _ptz != null;

  PtzDirection? _moving;
  PtzDirection? get moving => _moving;

  String? _message;

  /// A one-off problem to show (e.g. a pan/tilt command that failed).
  String? get message => _message;

  LiveVideoState get video => player.state.value;

  bool _disposed = false;

  Future<void> load() async {
    _login = await credentials.read(camera.deviceId);
    if (camera.ptz && _login != null) {
      _ptz = createPtz(host: camera.host, port: camera.onvifPort, credentials: _login!);
    }
    notifyListeners();
    await _play();
  }

  Future<void> retry() => _play();

  Future<void> toggleQuality() async {
    if (!hasSubStream) return;
    _highQuality = !_highQuality;
    notifyListeners();
    await _play();
  }

  /// Starts moving while a direction pad button is held.
  Future<void> startMove(PtzDirection direction) async {
    final ptz = _ptz;
    if (ptz == null || _moving == direction) return;
    HapticFeedback.selectionClick().ignore();
    _moving = direction;
    _message = null;
    notifyListeners();
    try {
      await ptz.move(direction);
    } on Object catch (e) {
      _moving = null;
      _message = 'Pan/tilt failed: ${_short(e)}';
      notifyListeners();
    }
  }

  Future<void> stopMove() async {
    final ptz = _ptz;
    if (ptz == null || _moving == null) return;
    _moving = null;
    notifyListeners();
    try {
      await ptz.stop();
    } on Object catch (e) {
      _message = 'Pan/tilt failed: ${_short(e)}';
      notifyListeners();
    }
  }

  void clearMessage() {
    _message = null;
    notifyListeners();
  }

  Future<void> _play() => player.open(camera.streamUri(_login, preferSub: !_highQuality));

  static String _short(Object error) {
    final text = '$error';
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    player.state.removeListener(notifyListeners);
    if (_moving != null) _ptz?.stop().ignore();
    player.dispose().ignore();
    super.dispose();
  }
}
