import 'package:flutter/services.dart';

/// Holds Android's Wi-Fi multicast lock while a search runs.
abstract interface class MulticastLock {
  Future<void> acquire();

  Future<void> release();
}

/// [MulticastLock] over the `universal_remote/network` channel (`NetworkBridge.kt`).
class AndroidMulticastLock implements MulticastLock {
  AndroidMulticastLock({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('universal_remote/network');

  final MethodChannel _channel;

  @override
  Future<void> acquire() => _invoke('acquireMulticastLock');

  @override
  Future<void> release() => _invoke('releaseMulticastLock');

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Not on Android (tests, desktop): multicast is not filtered there.
    }
  }
}
