import 'package:flutter/services.dart';

import '../../domain/services/app_launcher.dart';

/// [AppLauncher] over the `universal_remote/apps` channel (`AppLauncherBridge.kt`).
class AndroidAppLauncher implements AppLauncher {
  AndroidAppLauncher({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('universal_remote/apps');

  final MethodChannel _channel;

  @override
  Future<bool> isInstalled(String packageName) => _call('isInstalled', packageName);

  @override
  Future<bool> launch(String packageName) => _call('launch', packageName);

  @override
  Future<void> openStorePage(String packageName) => _call('openStorePage', packageName);

  Future<bool> _call(String method, String packageName) async {
    try {
      return await _channel.invokeMethod<bool>(method, {'package': packageName}) ?? false;
    } on MissingPluginException {
      // Not running on Android (tests, desktop).
      return false;
    }
  }
}
