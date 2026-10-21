import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:universal_remote/domain/cameras/camera_credentials.dart';
import 'package:universal_remote/domain/cameras/camera_services.dart';
import 'package:universal_remote/domain/models/ac_brand.dart';
import 'package:universal_remote/domain/devices/device.dart';
import 'package:universal_remote/domain/models/carrier_frequency_range.dart';
import 'package:universal_remote/domain/models/ir_packet.dart';
import 'package:universal_remote/domain/repositories/ac_brand_repository.dart';
import 'package:universal_remote/domain/repositories/device_repository.dart';
import 'package:universal_remote/domain/services/app_launcher.dart';
import 'package:universal_remote/domain/services/ir_transmitter.dart';
import 'package:universal_remote/ui/core/video/live_video_player.dart';
import 'package:universal_remote/ui/devices/camera_services.dart';

/// Records every packet instead of emitting it.
class FakeTransmitter implements IrTransmitter {
  FakeTransmitter({this.hasEmitter = true});

  bool hasEmitter;

  /// When set, [transmit] throws this platform error.
  String? failWithCode;

  /// Runs inside every [transmit] before it completes: await something to keep the
  /// send in flight, or throw to make this one transmission fail.
  Future<void> Function(IrPacket packet)? onTransmit;

  /// Packets that went out, in order.
  final List<IrPacket> sent = [];

  int _inFlight = 0;

  /// Most transmissions ever in flight at the same time.
  int maxInFlight = 0;

  @override
  Future<bool> hasIrEmitter() async => hasEmitter;

  @override
  Future<List<CarrierFrequencyRange>> getCarrierFrequencies() async =>
      hasEmitter ? const [CarrierFrequencyRange(minFrequency: 30000, maxFrequency: 60000)] : const [];

  @override
  Future<void> transmit(IrPacket packet) async {
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      final hook = onTransmit;
      if (hook != null) await hook(packet);
      final code = failWithCode;
      if (code != null) throw PlatformException(code: code);
      sent.add(packet);
    } finally {
      _inFlight--;
    }
  }
}

class InMemoryDeviceRepository implements DeviceRepository {
  InMemoryDeviceRepository([List<Device> initial = const []]) : devices = [...initial];

  final List<Device> devices;

  @override
  Future<List<Device>> getAll() async => List.unmodifiable(devices);

  @override
  Future<void> save(Device device) async {
    final index = devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.add(device);
    }
  }

  @override
  Future<Device?> update(String id, Device Function(Device current) change) async {
    final index = devices.indexWhere((d) => d.id == id);
    if (index < 0) return null;
    return devices[index] = change(devices[index]);
  }

  @override
  Future<void> delete(String id) async => devices.removeWhere((d) => d.id == id);
}

/// Pretends the packages in [installed] are installed; records what was opened.
class FakeAppLauncher implements AppLauncher {
  FakeAppLauncher({Set<String>? installed}) : installed = installed ?? {};

  final Set<String> installed;
  final List<String> launched = [];
  final List<String> storePages = [];

  @override
  Future<bool> isInstalled(String packageName) async => installed.contains(packageName);

  @override
  Future<bool> launch(String packageName) async {
    if (!installed.contains(packageName)) return false;
    launched.add(packageName);
    return true;
  }

  @override
  Future<void> openStorePage(String packageName) async => storePages.add(packageName);
}

class FakeAcBrandRepository implements AcBrandRepository {
  FakeAcBrandRepository([this.brands = defaultBrands]);

  static const List<AcBrand> defaultBrands = [
    AcBrand(id: 'casper', name: 'Casper', codeIds: [], rank: 3),
    AcBrand(id: 'daikin', name: 'Daikin', codeIds: ['daikin'], rank: 1),
    AcBrand(id: 'gree', name: 'Gree', codeIds: ['gree_yaw1f', 'gree_ybofb'], rank: 2),
    AcBrand(id: 'sharp', name: 'Sharp', codeIds: []),
  ];

  final List<AcBrand> brands;

  @override
  Future<List<AcBrand>> getBrands() async => brands;
}

// ------------------------------------------------------------------ Cameras

class InMemoryCredentialStore implements CredentialStore {
  final Map<String, CameraCredentials> saved = {};

  @override
  Future<CameraCredentials?> read(String deviceId) async => saved[deviceId];

  @override
  Future<void> write(String deviceId, CameraCredentials credentials) async => saved[deviceId] = credentials;

  @override
  Future<void> delete(String deviceId) async => saved.remove(deviceId);
}

/// Answers each stream path with a scripted result; unknown paths are "not found".
class FakeRtspProber implements RtspProber {
  FakeRtspProber([Map<String, RtspProbeResult>? results]) : results = results ?? {};

  /// Keyed by path plus query, e.g. `/stream1` or `/cam/realmonitor?channel=1&subtype=0`.
  final Map<String, RtspProbeResult> results;
  final List<Uri> probed = [];

  @override
  Future<RtspProbeResult> describe(Uri streamUri, CameraCredentials? credentials) async {
    probed.add(streamUri);
    final key = streamUri.hasQuery ? '${streamUri.path}?${streamUri.query}' : streamUri.path;
    return results[key] ?? const RtspNotFound(404);
  }
}

class FakeCameraDiscovery implements CameraDiscovery {
  FakeCameraDiscovery([this.cameras = const []]);

  final List<DiscoveredCamera> cameras;

  @override
  Stream<DiscoveredCamera> discover({Duration timeout = const Duration(seconds: 3)}) => Stream.fromIterable(cameras);
}

class FakePtzControl implements PtzControl {
  FakePtzControl({this.supported = true});

  final bool supported;
  final List<String> calls = [];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> move(PtzDirection direction) async => calls.add('move ${direction.name}');

  @override
  Future<void> stop() async => calls.add('stop');
}

/// Shows a placeholder instead of video; "plays" whatever it opens.
class FakeLivePlayer implements LiveVideoPlayer {
  final ValueNotifier<LiveVideoState> _state = ValueNotifier(LiveVideoState.idle);
  final List<Uri> opened = [];
  bool disposed = false;

  @override
  ValueListenable<LiveVideoState> get state => _state;

  @override
  Future<void> open(Uri uri) async {
    opened.add(uri);
    _state.value = const LiveVideoState(LiveVideoPhase.playing, width: 640, height: 360);
  }

  @override
  Widget buildView() => const Center(child: Text('FAKE VIDEO'));

  @override
  Future<void> dispose() async => disposed = true;
}

/// Camera services wired to fakes; keeps the last player and PTZ client for assertions.
class FakeCameras {
  FakeCameras({Map<String, RtspProbeResult>? streams, List<DiscoveredCamera> found = const [], this.ptzSupported = true})
      : prober = FakeRtspProber(streams),
        discovery = FakeCameraDiscovery(found);

  final InMemoryCredentialStore credentials = InMemoryCredentialStore();
  final FakeRtspProber prober;
  final FakeCameraDiscovery discovery;
  final bool ptzSupported;
  final List<FakePtzControl> ptzClients = [];
  final List<FakeLivePlayer> players = [];

  CameraServices get services => CameraServices(
        credentials: credentials,
        prober: prober,
        discovery: discovery,
        createPtz: ({required host, required port, required credentials}) {
          final ptz = FakePtzControl(supported: ptzSupported);
          ptzClients.add(ptz);
          return ptz;
        },
        createPlayer: () {
          final player = FakeLivePlayer();
          players.add(player);
          return player;
        },
      );
}
