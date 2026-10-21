import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_remote/data/repositories/device_repository_impl.dart';
import 'package:universal_remote/domain/devices/device.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  const ac = Device(
    id: 'a1',
    name: 'Bedroom AC',
    kind: DeviceKind.airConditioner,
    connection: IrConnection(codeId: 'daikin'),
    brandName: 'Daikin',
    room: 'Bedroom',
    state: AcState(mode: AcMode.dry, temperature: 27, fanSpeed: AcFanSpeed.low, swingVertical: true),
  );
  const camera = Device(
    id: 'c1',
    name: 'Gate camera',
    kind: DeviceKind.camera,
    connection: AppLinkConnection(packageName: 'com.xiaomi.smarthome', appName: 'Xiaomi Home'),
    brandName: 'Xiaomi Home',
  );

  DeviceRepositoryImpl create() => DeviceRepositoryImpl(preferences: SharedPreferences.getInstance());

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves, reloads, updates and deletes devices of any kind', () async {
    final repo = create();
    await repo.save(ac);
    await repo.save(camera);

    final all = await create().getAll();
    expect(all.map((d) => d.id), ['a1', 'c1']);
    expect(all.first.state, ac.state);
    expect(all.first.connection, const IrConnection(codeId: 'daikin'));
    expect(all.last.connection, camera.connection);
    expect(all.last.state, isNull);

    await repo.update('a1', (d) => d.copyWith(state: const AcState(temperature: 22)));
    await repo.delete('c1');
    final after = await create().getAll();
    expect((after.single.state! as AcState).temperature, 22);
  });

  test('migrates version 1 air conditioners and keeps the old key', () async {
    // The exact shape v1 wrote (a real paired Casper AC).
    const legacy = '[{"id":"hne0muv98y","name":"Casper AC - Working Room","brand":"Casper","code":"electra",'
        '"room":null,"state":{"power":true,"mode":"cool","temperature":26,"fan":"high","swingV":false,'
        '"swingH":false,"turbo":false}}]';
    SharedPreferences.setMockInitialValues({DeviceRepositoryImpl.legacyAcKey: legacy});

    final device = (await create().getAll()).single;
    expect(device.id, 'hne0muv98y');
    expect(device.name, 'Casper AC - Working Room');
    expect(device.kind, DeviceKind.airConditioner);
    expect(device.brandName, 'Casper');
    expect(device.connection, const IrConnection(codeId: 'electra'));
    expect(device.state, const AcState(temperature: 26, fanSpeed: AcFanSpeed.high));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DeviceRepositoryImpl.storageKey), isNotNull);
    expect(prefs.getString(DeviceRepositoryImpl.legacyAcKey), legacy);
  });

  test('once migrated, version 2 wins over the old key', () async {
    SharedPreferences.setMockInitialValues({
      DeviceRepositoryImpl.legacyAcKey: '[{"id":"old","name":"Old","code":"midea"}]',
      DeviceRepositoryImpl.storageKey: jsonEncode([camera.toJson()]),
    });
    expect((await create().getAll()).single.id, 'c1');
  });

  test('partial updates issued together keep each other\'s fields', () async {
    final repo = create();
    await repo.save(ac);
    // Same event-loop turn: the send queue saving a state while the user renames.
    await Future.wait([
      repo.update('a1', (d) => d.copyWith(name: 'Renamed')),
      repo.update('a1', (d) => d.copyWith(state: const AcState(temperature: 18))),
    ]);
    final stored = (await create().getAll()).single;
    expect(stored.name, 'Renamed');
    expect((stored.state! as AcState).temperature, 18);
    expect(await repo.update('missing', (d) => d), isNull);
  });

  test('a failed update does not block the next operations', () async {
    final repo = create();
    await repo.save(ac);
    await expectLater(repo.update('a1', (d) => throw StateError('boom')), throwsStateError);
    await repo.update('a1', (d) => d.copyWith(name: 'After'));
    expect((await repo.getAll()).single.name, 'After');
  });

  test('skips corrupt entries and keeps the rest', () async {
    SharedPreferences.setMockInitialValues({
      DeviceRepositoryImpl.storageKey: jsonEncode([
        camera.toJson(),
        {'broken': true},
        {'id': 'x', 'name': 'From the future', 'kind': 'robotVacuum', 'connection': {'type': 'ir', 'code': 'a'}},
      ]),
    });
    expect((await create().getAll()).single.id, 'c1');
  });
}
