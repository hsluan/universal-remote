import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_remote/data/repositories/ac_device_repository_impl.dart';
import 'package:universal_remote/domain/models/ac_device.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  const device = AcDevice(
    id: 'a1',
    name: 'Bedroom AC',
    brandName: 'Daikin',
    codeId: 'daikin',
    room: 'Bedroom',
    state: AcState(mode: AcMode.dry, temperature: 27, fanSpeed: AcFanSpeed.low, swingVertical: true),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves, reloads, updates and deletes devices', () async {
    final repo = AcDeviceRepositoryImpl(preferences: SharedPreferences.getInstance());
    await repo.save(device);
    await repo.save(device.copyWith(name: 'Second', state: const AcState(isPowerOn: false)).copyWithId('a2'));

    final reloaded = AcDeviceRepositoryImpl(preferences: SharedPreferences.getInstance());
    final all = await reloaded.getAll();
    expect(all.map((d) => d.id), ['a1', 'a2']);
    expect(all.first.state, device.state);
    expect(all.first.room, 'Bedroom');

    await reloaded.save(all.first.copyWith(state: all.first.state.copyWith(temperature: 22)));
    await reloaded.delete('a2');
    final after = await AcDeviceRepositoryImpl(preferences: SharedPreferences.getInstance()).getAll();
    expect(after.single.state.temperature, 22);
  });

  test('partial updates issued together keep each other\'s fields', () async {
    final repo = AcDeviceRepositoryImpl(preferences: SharedPreferences.getInstance());
    await repo.save(device);
    // Same event-loop turn: the send queue saving a state while the user renames.
    await Future.wait([
      repo.update('a1', (d) => d.copyWith(name: 'Renamed')),
      repo.update('a1', (d) => d.copyWith(state: const AcState(temperature: 18))),
    ]);
    final stored = (await AcDeviceRepositoryImpl(preferences: SharedPreferences.getInstance()).getAll()).single;
    expect(stored.name, 'Renamed');
    expect(stored.state.temperature, 18);
    expect(await repo.update('missing', (d) => d), isNull);
  });

  test('a failed update does not block the next operations', () async {
    final repo = AcDeviceRepositoryImpl(preferences: SharedPreferences.getInstance());
    await repo.save(device);
    await expectLater(repo.update('a1', (d) => throw StateError('boom')), throwsStateError);
    await repo.update('a1', (d) => d.copyWith(name: 'After'));
    expect((await repo.getAll()).single.name, 'After');
  });

  test('skips corrupt entries', () async {
    SharedPreferences.setMockInitialValues({
      AcDeviceRepositoryImpl.storageKey: '[{"id":"ok","name":"A","code":"midea"},{"broken":true}]',
    });
    final devices = await AcDeviceRepositoryImpl(preferences: SharedPreferences.getInstance()).getAll();
    expect(devices.single.id, 'ok');
    expect(devices.single.state.isPowerOn, isFalse);
  });
}

extension on AcDevice {
  AcDevice copyWithId(String id) =>
      AcDevice(id: id, name: name, brandName: brandName, codeId: codeId, room: room, state: state);
}
