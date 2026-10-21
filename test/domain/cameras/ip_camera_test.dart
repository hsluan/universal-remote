import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/cameras/camera_brand.dart';
import 'package:universal_remote/domain/cameras/camera_credentials.dart';
import 'package:universal_remote/domain/cameras/ip_camera.dart';
import 'package:universal_remote/domain/devices/device.dart';

void main() {
  const tapo = IpCamera(
    deviceId: 'cam1',
    name: 'Gate',
    brand: CameraBrand.tapo,
    host: '192.168.1.20',
    mainPath: '/stream1',
    subPath: '/stream2',
    onvifPort: 2020,
    ptz: true,
    room: 'Garage',
  );
  const login = CameraCredentials(user: 'gate', password: 'p@ss:w/rd');

  test('round-trips through a device without the password', () {
    final device = tapo.toDevice();
    expect(device.kind, DeviceKind.camera);
    expect(IpCamera.isIpCamera(device), isTrue);
    expect(device.toJson().toString(), isNot(contains('p@ss')));

    final copy = IpCamera.fromDevice(Device.fromJson(device.toJson()));
    expect(copy.brand, CameraBrand.tapo);
    expect(copy.host, '192.168.1.20');
    expect(copy.rtspPort, 554);
    expect(copy.mainPath, '/stream1');
    expect(copy.subPath, '/stream2');
    expect(copy.onvifPort, 2020);
    expect(copy.ptz, isTrue);
    expect(copy.room, 'Garage');
  });

  test('stream address percent-encodes the login and picks the small stream first', () {
    expect(tapo.streamUri(login).toString(), 'rtsp://gate:p%40ss%3Aw%2Frd@192.168.1.20:554/stream2');
    expect(tapo.streamUri(login, preferSub: false).path, '/stream1');
    expect(Uri.decodeComponent(tapo.streamUri(login).userInfo.split(':').last), 'p@ss:w/rd');
  });

  test('keeps a query in the path (Imou)', () {
    final uri = rtspUri(
      host: '10.0.0.9',
      port: 554,
      path: CameraBrand.imou.mainPaths.single,
      credentials: const CameraCredentials(user: 'admin', password: 'L2ABCD'),
    );
    expect(uri.toString(), 'rtsp://admin:L2ABCD@10.0.0.9:554/cam/realmonitor?channel=1&subtype=0');
  });

  test('without a sub-stream, the main stream plays', () {
    const single = IpCamera(deviceId: 'c', name: 'C', brand: CameraBrand.other, host: 'h', mainPath: '/live');
    expect(single.streamUri(null).toString(), 'rtsp://h:554/live');
  });

  test('brands carry their researched conventions', () {
    expect(CameraBrand.ezviz.mainPaths, ['/ch1/main', '/Streaming/Channels/101']);
    expect(CameraBrand.hikvision.subPaths, ['/Streaming/Channels/102']);
    expect(CameraBrand.tapo.onvifPort, 2020);
    expect(CameraBrand.tapo.defaultUser, isEmpty);
    expect(CameraBrand.fromId('imou'), CameraBrand.imou);
    expect(CameraBrand.fromId('nope'), isNull);
  });

  test('credentials never print the password', () {
    expect('$login', isNot(contains('p@ss')));
  });

  test('other kinds and protocols are not IP cameras', () {
    const plug = Device(
      id: 'p',
      name: 'Plug',
      kind: DeviceKind.plug,
      connection: LanConnection(protocol: 'shelly', host: '1.2.3.4'),
    );
    expect(IpCamera.isIpCamera(plug), isFalse);
    expect(() => IpCamera.fromDevice(plug), throwsArgumentError);
  });
}
