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

/// Makers' apps the user can link devices to, verified against their Google Play
/// listings (Vietnam region) in October 2026.
///
/// Each package must also be listed under `<queries>` in AndroidManifest.xml, or
/// Android 11+ hides it (a test checks this).
const List<VendorApp> vendorApps = [
  VendorApp(
    packageName: 'com.xiaomi.smarthome',
    name: 'Xiaomi Home',
    kinds: {DeviceKind.camera, DeviceKind.light, DeviceKind.plug, DeviceKind.fan, DeviceKind.airConditioner},
  ),
  VendorApp(packageName: 'com.mm.android.smartlifeiot', name: 'Imou Life', kinds: {DeviceKind.camera}),
  VendorApp(packageName: 'com.ezviz', name: 'EZVIZ', kinds: {DeviceKind.camera}),
  VendorApp(packageName: 'com.tplink.iot', name: 'Tapo', kinds: {DeviceKind.camera, DeviceKind.light, DeviceKind.plug}),
  VendorApp(packageName: 'com.connect.enduser', name: 'Hik-Connect', kinds: {DeviceKind.camera}),
  VendorApp(packageName: 'com.tuya.smartlife', name: 'Smart Life', kinds: {
    DeviceKind.light,
    DeviceKind.plug,
    DeviceKind.fan,
    DeviceKind.camera,
    DeviceKind.airConditioner,
  }),
  VendorApp(packageName: 'com.tuya.smart', name: 'Tuya Smart', kinds: {
    DeviceKind.light,
    DeviceKind.plug,
    DeviceKind.fan,
    DeviceKind.camera,
  }),
  VendorApp(packageName: 'com.coolkit', name: 'eWeLink', kinds: {DeviceKind.plug, DeviceKind.light, DeviceKind.fan}),
  VendorApp(packageName: 'cloud.shelly.smartcontrol', name: 'Shelly Smart Control', kinds: {DeviceKind.plug, DeviceKind.light}),
  VendorApp(packageName: 'com.wizconnected.wiz2', name: 'WiZ', kinds: {DeviceKind.light}),
  VendorApp(packageName: 'com.yeelight.yeelight_fluid', name: 'Yeelight', kinds: {DeviceKind.light}),
  VendorApp(packageName: 'com.yeelight.cherry', name: 'Yeelight Classic', kinds: {DeviceKind.light}),
  VendorApp(packageName: 'vn.co.honda.hondacrm', name: 'My Honda+', kinds: {DeviceKind.vehicle}),
  VendorApp(packageName: 'com.honda.ms.dm.sab', name: 'Honda RoadSync', kinds: {DeviceKind.vehicle}),
  // Needs Android 8+: listed for newer phones, it will not install on Android 7.
  VendorApp(
    packageName: 'jp.co.yamahamotor.yamahamotorcycleconnect.sccu',
    name: 'Yamaha Motorcycle Connect',
    kinds: {DeviceKind.vehicle},
  ),
  VendorApp(packageName: 'com.vinfast.companion.app', name: 'VinFast', kinds: {DeviceKind.vehicle}),
  VendorApp(packageName: 'vn.vinfast.ecosystem', name: 'VinFast E-Scooter', kinds: {DeviceKind.vehicle}),
];

/// Apps for [kind], in catalog order.
List<VendorApp> vendorAppsFor(DeviceKind kind) => [for (final app in vendorApps) if (app.kinds.contains(kind)) app];
