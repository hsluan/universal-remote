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
