import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/cameras/camera_brand.dart';
import 'package:universal_remote/domain/cameras/camera_credentials.dart';
import 'package:universal_remote/domain/cameras/camera_services.dart';
import 'package:universal_remote/domain/cameras/ip_camera.dart';
import 'package:universal_remote/ui/features/camera_setup/view_models/camera_setup_view_model.dart';

import '../helpers/fakes.dart';

void main() {
  late InMemoryDeviceRepository repository;
  late FakeCameras cameras;

  CameraSetupViewModel create(FakeCameras fakes) {
    cameras = fakes;
    repository = InMemoryDeviceRepository();
    final services = fakes.services;
    return CameraSetupViewModel(
      repository: repository,
      credentials: services.credentials,
      prober: services.prober,
      discovery: services.discovery,
      createPtz: services.createPtz,
    );
  }

  Future<CameraSetupViewModel> filled(FakeCameras fakes, CameraBrand brand) async {
    final vm = create(fakes);
    await vm.chooseBrand(brand);
    vm
      ..setHost('192.168.1.20')
      ..setUser(brand == CameraBrand.tapo ? 'gate' : 'admin')
      ..setPassword('secret');
    return vm;
  }

  test('EZVIZ: falls through to the second main path, finds the sub stream and pan/tilt, then saves', () async {
    final vm = await filled(
      FakeCameras(streams: {
        '/Streaming/Channels/101': const RtspStreamFound(videoCodec: 'H265'),
        '/Streaming/Channels/102': const RtspStreamFound(videoCodec: 'H264'),
      }),
      CameraBrand.ezviz,
    );
    expect(vm.onvifPort, 80);
    await vm.test();

    expect(vm.testStatus, CameraTestStatus.passed);
    expect(vm.videoCodec, 'H265');
    expect(vm.hasSubStream, isTrue);
    expect(vm.ptzSupported, isTrue);
    expect([for (final uri in cameras.prober.probed) uri.path], ['/ch1/main', '/Streaming/Channels/101', '/Streaming/Channels/102']);

    vm
      ..setName('Front door')
      ..setRoom('Gate');
    final device = await vm.save();
    final camera = IpCamera.fromDevice(device!);
    expect(camera.mainPath, '/Streaming/Channels/101');
    expect(camera.subPath, '/Streaming/Channels/102');
    expect(camera.ptz, isTrue);
    expect(camera.room, 'Gate');
    expect(repository.devices.single.name, 'Front door');
    expect(cameras.credentials.saved[device.id], const CameraCredentials(user: 'admin', password: 'secret'));
  });

  test('a refused login explains where the password comes from', () async {
    final vm = await filled(FakeCameras(streams: {'/stream1': const RtspUnauthorized()}), CameraBrand.tapo);
    await vm.test();
    expect(vm.testStatus, CameraTestStatus.failed);
    expect(vm.testMessage, contains('refused'));
    expect(vm.testMessage, contains('Camera Account'));
    expect(vm.canSave, isFalse);
    expect(await vm.save(), isNull);
  });

  test('an unreachable camera points at the address and RTSP', () async {
    final vm = await filled(
      FakeCameras(streams: {'/cam/realmonitor?channel=1&subtype=0': const RtspUnreachable('Connection refused')}),
      CameraBrand.imou,
    );
    await vm.test();
    expect(vm.testMessage, contains('No camera answered at 192.168.1.20:554'));
  });

  test('no known path: suggests turning RTSP on', () async {
    final vm = await filled(FakeCameras(), CameraBrand.hikvision);
    await vm.test();
    expect(vm.testMessage, contains('none of the usual Hikvision stream paths'));
  });

  test('editing the form clears a passed test', () async {
    final vm = await filled(FakeCameras(streams: {'/stream1': const RtspStreamFound()}), CameraBrand.tapo);
    await vm.test();
    expect(vm.canSave, isTrue);
    vm.setPassword('other');
    expect(vm.testStatus, CameraTestStatus.idle);
    expect(vm.canSave, isFalse);
  });

  test('other brands need a stream path; a found camera fills in the address', () async {
    final vm = create(FakeCameras(
      streams: {'/live/ch0': const RtspStreamFound()},
      found: [const DiscoveredCamera(host: '192.168.1.30', onvifPort: 8899, hardware: 'XM530')],
    ));
    await vm.chooseBrand(CameraBrand.other);
    await vm.search();
    expect(vm.found.single.host, '192.168.1.30');
    vm
      ..pick(vm.found.single)
      ..setUser('admin')
      ..setPassword('x');
    expect(vm.canTest, isFalse);
    vm.setCustomPath('live/ch0');
    await vm.test();
    expect(vm.testStatus, CameraTestStatus.passed);
    expect(vm.onvifPort, 8899);
    expect(IpCamera.fromDevice((await vm.save())!).mainPath, '/live/ch0');
  });
}
