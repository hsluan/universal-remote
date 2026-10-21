import 'package:flutter/foundation.dart';

import '../../../../domain/devices/device.dart';
import '../../../../domain/devices/vendor_apps.dart';
import '../../../../domain/repositories/device_repository.dart';
import '../../../../domain/services/app_launcher.dart';
import '../../../core/theme/device_kind_style.dart';

/// Adds a device whose only remote is its maker's app: the home card opens that app.
class AppLinkSetupViewModel extends ChangeNotifier {
  AppLinkSetupViewModel({
    required this.kind,
    required this.launcher,
    required this.repository,
    List<VendorApp>? apps,
  }) : _apps = apps ?? vendorAppsFor(kind);

  static const List<String> roomSuggestions = ['Living room', 'Bedroom', 'Kitchen', 'Office', 'Garage'];

  final DeviceKind kind;
  final AppLauncher launcher;
  final DeviceRepository repository;

  List<VendorApp> _apps;

  /// Apps that control this kind of device, installed ones first once [load] ran.
  List<VendorApp> get apps => _apps;

  final Set<String> _installed = {};
  bool isInstalled(VendorApp app) => _installed.contains(app.packageName);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  VendorApp? _selected;
  VendorApp? get selected => _selected;

  String _name = '';
  String get name => _name;

  String? _room;
  String? get room => _room;

  bool get canSave => _selected != null && _name.trim().isNotEmpty;

  /// Checks which apps are installed and preselects the first installed one.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    for (final app in _apps) {
      if (await launcher.isInstalled(app.packageName)) _installed.add(app.packageName);
    }
    _apps = [..._apps.where(isInstalled), ..._apps.where((app) => !isInstalled(app))];
    final firstInstalled = _apps.where(isInstalled).firstOrNull;
    if (firstInstalled != null) select(firstInstalled);
    _isLoading = false;
    notifyListeners();
  }

  void select(VendorApp app) {
    final previousDefault = _defaultName(_selected);
    _selected = app;
    // Keep a name the user typed; follow the app while it is still the suggested one.
    if (_name.isEmpty || _name == previousDefault) _name = _defaultName(app);
    notifyListeners();
  }

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setRoom(String? value) {
    _room = value;
    notifyListeners();
  }

  Future<void> install(VendorApp app) => launcher.openStorePage(app.packageName);

  /// Saves the shortcut and returns it, or `null` when the form is incomplete.
  Future<Device?> save() async {
    final app = _selected;
    if (app == null || !canSave) return null;
    final device = Device(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: _name.trim(),
      kind: kind,
      connection: AppLinkConnection(packageName: app.packageName, appName: app.name),
      brandName: app.name,
      room: _room,
    );
    await repository.save(device);
    return device;
  }

  String _defaultName(VendorApp? app) => app == null ? '' : '${app.name} ${kind.label.toLowerCase()}';
}
