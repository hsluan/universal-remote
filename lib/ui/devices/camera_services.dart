import '../../domain/cameras/camera_credentials.dart';
import '../../domain/cameras/camera_services.dart';
import '../core/video/live_video_player.dart';

/// Everything the camera module needs; the composition root supplies the real network,
/// storage and player, tests supply fakes.
class CameraServices {
  const CameraServices({
    required this.credentials,
    required this.prober,
    required this.discovery,
    required this.createPtz,
    required this.createPlayer,
  });

  final CredentialStore credentials;
  final RtspProber prober;
  final CameraDiscovery discovery;
  final PtzControlFactory createPtz;
  final LiveVideoPlayerFactory createPlayer;
}
