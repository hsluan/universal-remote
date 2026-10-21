import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/devices/device.dart';
import 'package:universal_remote/domain/devices/vendor_apps.dart';
import 'package:universal_remote/domain/models/ac_device.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  Device roundTrip(Device device) =>
      Device.fromJson(jsonDecode(jsonEncode(device.toJson())) as Map<String, dynamic>);

  group('Device JSON', () {
    test('round-trips every connection type', () {
      const connections = <DeviceConnection>[
        IrConnection(codeId: 'electra'),
        LanConnection(protocol: 'shelly', host: '192.168.1.40', port: 80, deviceId: 'shellyplug-s-1A2B'),
        BleConnection(protocol: 'itag', address: 'FF:FF:12:34:56:78'),
        AppLinkConnection(packageName: 'com.xiaomi.smarthome', appName: 'Xiaomi Home'),
      ];
      for (final connection in connections) {
        final device = Device(id: 'd', name: 'D', kind: DeviceKind.plug, connection: connection, room: 'Garage');
        final copy = roundTrip(device);
        expect(copy.connection, connection);
        expect(copy.room, 'Garage');
        expect(copy.kind, DeviceKind.plug);
      }
    });

    test('keeps a connection type and a state it cannot read', () {
      final json = {
        'id': 'd',
        'name': 'Future plug',
        'kind': 'plug',
        'connection': {'type': 'zigbee', 'ieee': '00:12'},
        'state': {'power': true, 'watts': 42},
      };
      final device = Device.fromJson(json);
      expect(device.connection, isA<UnknownConnection>());
      expect(device.toJson()['connection'], json['connection']);
      expect(device.toJson()['state'], json['state']);
    });

    test('reads AC state as AcState', () {
      const device = Device(
        id: 'a',
        name: 'AC',
        kind: DeviceKind.airConditioner,
        connection: IrConnection(codeId: 'gree_yaw1f'),
        state: AcState(temperature: 21),
      );
      expect(roundTrip(device).state, const AcState(temperature: 21));
    });

    test('rejects an unknown kind', () {
      expect(
        () => Device.fromJson({'id': 'x', 'name': 'X', 'kind': 'robotVacuum', 'connection': {'type': 'ir', 'code': 'a'}}),
        throwsFormatException,
      );
    });
  });

  group('AcDevice view', () {
    const ac = AcDevice(id: 'a', name: 'AC', brandName: 'Casper', codeId: 'electra', room: 'Office');

    test('converts to a device and back', () {
      final device = ac.toDevice();
      expect(AcDevice.isAc(device), isTrue);
      final view = AcDevice.fromDevice(device);
      expect(view.codeId, 'electra');
      expect(view.room, 'Office');
      expect(view.state, const AcState(isPowerOn: false));
    });

    test('refuses other kinds and connections', () {
      const shortcut = Device(
        id: 's',
        name: 'Shortcut',
        kind: DeviceKind.airConditioner,
        connection: AppLinkConnection(packageName: 'com.xiaomi.smarthome', appName: 'Xiaomi Home'),
      );
      expect(AcDevice.isAc(shortcut), isFalse);
      expect(() => AcDevice.fromDevice(shortcut), throwsArgumentError);
    });
  });

  test('every vendor app is declared in AndroidManifest.xml <queries>', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final app in vendorApps) {
      expect(manifest, contains('<package android:name="${app.packageName}"/>'), reason: '${app.name} is not visible on Android 11+');
    }
    expect(vendorApps.map((a) => a.packageName).toSet(), hasLength(vendorApps.length));
  });
}
