import 'package:flutter/services.dart';

/// User-facing explanation of a failed IR transmission.
String describeTransmitError(Object error) {
  if (error is MissingPluginException) {
    return 'IR only works in the Android app on a phone with an IR blaster.';
  }
  if (error is PlatformException && error.code.startsWith('NO_IR')) {
    return 'This phone has no IR blaster, so the command could not be sent.';
  }
  return 'Could not send the command. Try again.';
}
