import 'device_kind.dart';

/// A maker's app that a device can be linked to.
class VendorApp {
  const VendorApp({required this.packageName, required this.name, required this.kinds});

  /// Android package, as in the app's Google Play URL.
  final String packageName;
  final String name;

  /// Kinds of devices this app controls.
  final Set<DeviceKind> kinds;
}

/// Makers' apps the user can link devices to.
///
/// Package names come from the apps' Google Play pages. Each one must also be listed
/// under `<queries>` in AndroidManifest.xml, or Android 11+ hides it (a test checks this).
const List<VendorApp> vendorApps = [
  VendorApp(
    packageName: 'com.xiaomi.smarthome',
    name: 'Xiaomi Home',
    kinds: {DeviceKind.camera, DeviceKind.light, DeviceKind.plug, DeviceKind.fan, DeviceKind.airConditioner},
  ),
  VendorApp(packageName: 'com.tplink.iot', name: 'Tapo', kinds: {DeviceKind.camera, DeviceKind.light, DeviceKind.plug}),
  VendorApp(packageName: 'com.ezviz', name: 'EZVIZ', kinds: {DeviceKind.camera}),
  VendorApp(packageName: 'com.tuya.smartlife', name: 'Smart Life', kinds: {
    DeviceKind.light,
    DeviceKind.plug,
    DeviceKind.fan,
    DeviceKind.camera,
    DeviceKind.airConditioner,
  }),
  VendorApp(packageName: 'com.coolkit', name: 'eWeLink', kinds: {DeviceKind.plug, DeviceKind.light, DeviceKind.fan}),
  VendorApp(packageName: 'com.yeelight.cherry', name: 'Yeelight', kinds: {DeviceKind.light}),
];

/// Apps for [kind], in catalog order.
List<VendorApp> vendorAppsFor(DeviceKind kind) => [for (final app in vendorApps) if (app.kinds.contains(kind)) app];
