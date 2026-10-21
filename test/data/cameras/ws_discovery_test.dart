import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/data/cameras/ws_discovery.dart';
import 'package:universal_remote/data/services/multicast_lock.dart';
import 'package:universal_remote/domain/cameras/camera_services.dart';

String probeMatches({required String xaddrs, String scopes = ''}) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope" '
    'xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"><SOAP-ENV:Body><d:ProbeMatches><d:ProbeMatch>'
    '<d:Types>dn:NetworkVideoTransmitter</d:Types><d:Scopes>$scopes</d:Scopes><d:XAddrs>$xaddrs</d:XAddrs>'
    '</d:ProbeMatch></d:ProbeMatches></SOAP-ENV:Body></SOAP-ENV:Envelope>';

class RecordingLock implements MulticastLock {
  final List<String> calls = [];

  @override
  Future<void> acquire() async => calls.add('acquire');

  @override
  Future<void> release() async => calls.add('release');
}

void main() {
  final sender = InternetAddress('192.168.1.99');

  test('reads address, ONVIF port, name and hardware from a ProbeMatch', () {
    final cameras = WsDiscovery.parseProbeMatches(
      probeMatches(
        xaddrs: 'http://[fe80::1]:2020/onvif/device_service http://192.168.1.20:2020/onvif/device_service',
        scopes: 'onvif://www.onvif.org/name/TP-IPC onvif://www.onvif.org/hardware/C200 onvif://www.onvif.org/Profile/Streaming',
      ),
      sender,
    );
    expect(cameras.single.host, '192.168.1.20');
    expect(cameras.single.onvifPort, 2020);
    expect(cameras.single.label, 'C200 · TP-IPC');
  });

  test('falls back to the sender when the address is not IPv4', () {
    final camera = WsDiscovery.parseProbeMatches(probeMatches(xaddrs: 'http://camera.local/onvif/device_service'), sender).single;
    expect(camera.host, '192.168.1.99');
    expect(camera.onvifPort, 80);
  });

  test('ignores garbage', () {
    expect(WsDiscovery.parseProbeMatches('not xml', sender), isEmpty);
  });

  test('the probe asks for network video transmitters', () {
    final probe = WsDiscovery.probeMessage('1234');
    expect(probe, contains('<d:Types>dn:NetworkVideoTransmitter</d:Types>'));
    expect(probe, contains('uuid:1234'));
  });

  test('sends the probe, collects unique answers and holds the multicast lock meanwhile', () async {
    // A fake camera on loopback answers every probe (twice: the probe is sent twice).
    final responder = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final probes = <String>[];
    responder.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = responder.receive();
      if (datagram == null) return;
      probes.add(utf8.decode(datagram.data));
      responder.send(
        utf8.encode(probeMatches(xaddrs: 'http://127.0.0.1:8899/onvif/device_service')),
        datagram.address,
        datagram.port,
      );
    });
    final lock = RecordingLock();

    final found = await WsDiscovery(target: InternetAddress.loopbackIPv4, port: responder.port, multicastLock: lock)
        .discover(timeout: const Duration(milliseconds: 800))
        .toList();
    responder.close();

    expect(probes, hasLength(2));
    expect(probes.first, contains('NetworkVideoTransmitter'));
    expect(found, [const DiscoveredCamera(host: '127.0.0.1', onvifPort: 8899)]);
    expect(lock.calls, ['acquire', 'release']);
  });
}
