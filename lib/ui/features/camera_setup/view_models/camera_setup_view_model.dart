import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../domain/cameras/camera_brand.dart';
import '../../../../domain/cameras/camera_credentials.dart';
import '../../../../domain/cameras/camera_services.dart';
import '../../../../domain/cameras/ip_camera.dart';
import '../../../../domain/devices/device.dart';
import '../../../../domain/repositories/device_repository.dart';

enum CameraSetupStep { brand, connect }

enum CameraTestStatus { idle, testing, passed, failed }

/// Adds an IP camera: brand → address and login → connection test → name.
class CameraSetupViewModel extends ChangeNotifier {
  CameraSetupViewModel({
    required this.repository,
    required this.credentials,
    required this.prober,
    required this.discovery,
    required this.createPtz,
  });

  static const List<String> roomSuggestions = ['Living room', 'Bedroom', 'Gate', 'Garage', 'Kitchen'];

  final DeviceRepository repository;
  final CredentialStore credentials;
  final RtspProber prober;
  final CameraDiscovery discovery;
  final PtzControlFactory createPtz;

  CameraSetupStep _step = CameraSetupStep.brand;
  CameraSetupStep get step => _step;

  CameraBrand _brand = CameraBrand.other;
  CameraBrand get brand => _brand;

  // ---------------------------------------------------------------- Search

  bool _searching = false;
  bool get searching => _searching;

  final List<DiscoveredCamera> _found = [];
  List<DiscoveredCamera> get found => List.unmodifiable(_found);

  bool _searched = false;

  /// Whether a search ran (so "nothing found" can be told apart from "not searched").
  bool get searched => _searched;

  StreamSubscription<DiscoveredCamera>? _search;
  Completer<void>? _searchDone;

  // ------------------------------------------------------------------ Form

  String _host = '';
  String get host => _host;

  int _rtspPort = CameraBrand.rtspPort;
  int get rtspPort => _rtspPort;

  int _onvifPort = 80;
  int get onvifPort => _onvifPort;

  String _user = '';
  String get user => _user;

  String _password = '';
  String get password => _password;

  /// Stream path for [CameraBrand.other], e.g. `/live/ch0`.
  String _customPath = '';
  String get customPath => _customPath;

  // ------------------------------------------------------------------ Test

  CameraTestStatus _testStatus = CameraTestStatus.idle;
  CameraTestStatus get testStatus => _testStatus;

  String? _testMessage;
  String? get testMessage => _testMessage;

  String? _mainPath;
  String? _subPath;
  String? _codec;
  bool _ptz = false;

  String? get videoCodec => _codec;
  bool get ptzSupported => _ptz;
  bool get hasSubStream => _subPath != null;

  // ------------------------------------------------------------- Name/room

  String _name = '';
  String get name => _name;

  String? _room;
  String? get room => _room;

  List<String> _existingNames = const [];

  bool get canTest =>
      _isValidHost(_host) &&
      _password.isNotEmpty &&
      _user.trim().isNotEmpty &&
      (_brand != CameraBrand.other || _customPath.trim().isNotEmpty) &&
      _testStatus != CameraTestStatus.testing;

  bool get canSave => _testStatus == CameraTestStatus.passed && _name.trim().isNotEmpty;

  Future<void> chooseBrand(CameraBrand brand) async {
    _brand = brand;
    _user = brand.defaultUser;
    _onvifPort = brand.onvifPort;
    _resetTest();
    _existingNames = [for (final d in await repository.getAll()) d.name];
    _name = _uniqueName('${brand == CameraBrand.other ? 'IP' : brand.label} camera');
    _step = CameraSetupStep.connect;
    notifyListeners();
  }

  /// Wizard back button; returns `false` on the first step, where the route should pop.
  bool back() {
    if (_step == CameraSetupStep.brand) return false;
    _stopSearch();
    _step = CameraSetupStep.brand;
    notifyListeners();
    return true;
  }

  Future<void> search() async {
    _stopSearch();
    _found.clear();
    _searching = true;
    _searched = true;
    notifyListeners();
    final done = Completer<void>();
    _searchDone = done;
    _search = discovery.discover().listen(
      (camera) {
        _found.add(camera);
        notifyListeners();
      },
      onError: (Object _) {},
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: false,
    );
    await done.future;
    _searching = false;
    _search = null;
    _searchDone = null;
    notifyListeners();
  }

  void pick(DiscoveredCamera camera) {
    _host = camera.host;
    _onvifPort = camera.onvifPort;
    _resetTest();
    notifyListeners();
  }

  void setHost(String value) => _edit(() => _host = value.trim());
  void setUser(String value) => _edit(() => _user = value);
  void setPassword(String value) => _edit(() => _password = value);
  void setCustomPath(String value) => _edit(() => _customPath = value.trim());
  void setRtspPort(String value) => _edit(() => _rtspPort = int.tryParse(value) ?? CameraBrand.rtspPort);
  void setOnvifPort(String value) => _edit(() => _onvifPort = int.tryParse(value) ?? _brand.onvifPort);

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setRoom(String? value) {
    _room = value;
    notifyListeners();
  }

  /// Finds a stream path the camera accepts with this login, then checks pan/tilt.
  Future<void> test() async {
    if (!canTest) return;
    _testStatus = CameraTestStatus.testing;
    _testMessage = null;
    notifyListeners();

    final login = CameraCredentials(user: _user.trim(), password: _password);
    final mainPaths = _brand == CameraBrand.other ? [_normalizedPath(_customPath)] : _brand.mainPaths;
    _mainPath = null;
    _subPath = null;
    for (final path in mainPaths) {
      final result = await prober.describe(_uri(path, login), login);
      switch (result) {
        case RtspStreamFound(:final videoCodec):
          _mainPath = path;
          _codec = videoCodec;
        case RtspUnauthorized():
          return _fail('The camera refused this user or password. ${_brand.passwordHint}');
        case RtspUnreachable(:final reason):
          return _fail('No camera answered at $_host:$_rtspPort ($reason). Check the address, that the phone is on '
              'the same Wi-Fi, and that RTSP is enabled on the camera.');
        case RtspNotFound():
          continue;
      }
      if (_mainPath != null) break;
    }
    if (_mainPath == null) {
      return _fail(_brand == CameraBrand.other
          ? 'The camera answered but has no stream at that path. Check the path in its manual.'
          : 'The camera answered but none of the usual ${_brand.label} stream paths. It may need a firmware update, '
              'or RTSP turned on in its app.');
    }
    for (final path in _brand.subPaths) {
      if (await prober.describe(_uri(path, login), login) is RtspStreamFound) {
        _subPath = path;
        break;
      }
    }
    _ptz = await createPtz(host: _host, port: _onvifPort, credentials: login)
        .isSupported()
        .timeout(const Duration(seconds: 8), onTimeout: () => false);
    _testStatus = CameraTestStatus.passed;
    notifyListeners();
  }

  /// Saves the camera (login in secure storage) and returns it, or `null` when not ready.
  Future<Device?> save() async {
    final mainPath = _mainPath;
    if (!canSave || mainPath == null) return null;
    final camera = IpCamera(
      deviceId: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: _name.trim(),
      brand: _brand,
      host: _host,
      rtspPort: _rtspPort,
      mainPath: mainPath,
      subPath: _subPath,
      onvifPort: _onvifPort,
      ptz: _ptz,
      room: _room,
    );
    await credentials.write(camera.deviceId, CameraCredentials(user: _user.trim(), password: _password));
    final device = camera.toDevice();
    await repository.save(device);
    return device;
  }

  Uri _uri(String path, CameraCredentials login) => rtspUri(host: _host, port: _rtspPort, path: path, credentials: login);

  void _fail(String message) {
    _testStatus = CameraTestStatus.failed;
    _testMessage = message;
    notifyListeners();
  }

  void _edit(VoidCallback change) {
    change();
    _resetTest();
    notifyListeners();
  }

  void _resetTest() {
    _testStatus = CameraTestStatus.idle;
    _testMessage = null;
    _mainPath = null;
    _subPath = null;
    _codec = null;
    _ptz = false;
  }

  void _stopSearch() {
    _search?.cancel();
    _search = null;
    _searching = false;
    // A cancelled subscription never reports done: finish the waiting search() here.
    final done = _searchDone;
    if (done != null && !done.isCompleted) done.complete();
    _searchDone = null;
  }

  String _uniqueName(String base) {
    if (!_existingNames.contains(base)) return base;
    var n = 2;
    while (_existingNames.contains('$base $n')) {
      n++;
    }
    return '$base $n';
  }

  static String _normalizedPath(String path) => path.startsWith('/') ? path : '/$path';

  static bool _isValidHost(String host) => InternetAddress.tryParse(host) != null || RegExp(r'^[\w.-]+$').hasMatch(host);

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopSearch();
    super.dispose();
  }
}
