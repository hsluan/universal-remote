import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/data/cameras/onvif_ptz_control.dart';
import 'package:universal_remote/domain/cameras/camera_credentials.dart';
import 'package:universal_remote/domain/cameras/camera_services.dart';
import 'package:xml/xml.dart';

String envelope(String body) =>
    '<?xml version="1.0"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope" '
    'xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:trt="http://www.onvif.org/ver10/media/wsdl" '
    'xmlns:tptz="http://www.onvif.org/ver20/ptz/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">'
    '<SOAP-ENV:Body>$body</SOAP-ENV:Body></SOAP-ENV:Envelope>';

const dateTime = '<tds:GetSystemDateAndTimeResponse><tds:SystemDateAndTime><tt:UTCDateTime>'
    '<tt:Date><tt:Year>2026</tt:Year><tt:Month>10</tt:Month><tt:Day>21</tt:Day></tt:Date>'
    '<tt:Time><tt:Hour>9</tt:Hour><tt:Minute>30</tt:Minute><tt:Second>5</tt:Second></tt:Time>'
    '</tt:UTCDateTime></tds:SystemDateAndTime></tds:GetSystemDateAndTimeResponse>';

/// Capabilities as cameras often report them: an internal address the phone cannot reach.
String capabilities({bool ptz = true}) => '<tds:GetCapabilitiesResponse><tds:Capabilities>'
    '<tt:Media><tt:XAddr>http://10.0.0.5:2020/onvif/media_service</tt:XAddr></tt:Media>'
    '${ptz ? '<tt:PTZ><tt:XAddr>http://10.0.0.5:2020/onvif/ptz_service</tt:XAddr></tt:PTZ>' : ''}'
    '</tds:Capabilities></tds:GetCapabilitiesResponse>';

const profiles = '<trt:GetProfilesResponse>'
    '<trt:Profiles token="profile_sub"><tt:Name>sub</tt:Name></trt:Profiles>'
    '<trt:Profiles token="profile_main"><tt:Name>main</tt:Name><tt:PTZConfiguration token="ptz0"/></trt:Profiles>'
    '</trt:GetProfilesResponse>';

/// Answers ONVIF calls by SOAP action, recording each request body.
class FakeOnvifCamera {
  FakeOnvifCamera._(this._server);

  final HttpServer _server;
  final List<String> actions = [];
  final List<String> bodies = [];
  bool ptz = true;
  bool rejectLogin = false;

  int get port => _server.port;

  static Future<FakeOnvifCamera> start() async {
    final camera = FakeOnvifCamera._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    camera._server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final action = request.headers.contentType?.parameters['action']?.split('/').last ?? '';
      camera.actions.add(action);
      camera.bodies.add(body);
      final authed = body.contains('<UsernameToken>');
      String reply;
      var status = 200;
      if (action == 'GetSystemDateAndTime') {
        reply = dateTime;
      } else if (!authed || camera.rejectLogin) {
        status = 400;
        reply = '<SOAP-ENV:Fault><SOAP-ENV:Reason><SOAP-ENV:Text xml:lang="en">Sender not Authorized</SOAP-ENV:Text>'
            '</SOAP-ENV:Reason></SOAP-ENV:Fault>';
      } else {
        reply = switch (action) {
          'GetCapabilities' => capabilities(ptz: camera.ptz),
          'GetProfiles' => profiles,
          'ContinuousMove' => '<tptz:ContinuousMoveResponse/>',
          'Stop' => '<tptz:StopResponse/>',
          _ => '',
        };
      }
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType('application', 'soap+xml', charset: 'utf-8')
        ..write(envelope(reply));
      await request.response.close();
    });
    return camera;
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  const login = CameraCredentials(user: 'gate', password: 'secret');

  group('pure helpers', () {
    test('UsernameToken digest matches the ONVIF Application Programmer\'s Guide example', () {
      final token = OnvifPtzControl.usernameToken(
        user: 'user',
        password: 'userpassword',
        nonce: base64.decode('LKqI6G/AikKCQrN0zqZFlg=='),
        created: DateTime.utc(2010, 9, 16, 7, 50, 45),
      );
      expect(token, contains('>tuOSpGlFlIXsozq4HFNeeGeFLEI=</Password>'));
      expect(token, contains('>LKqI6G/AikKCQrN0zqZFlg==</Nonce>'));
      expect(token, contains('>2010-09-16T07:50:45Z</Created>'));
    });

    test('reads the camera clock and picks the profile with PTZ', () {
      expect(OnvifPtzControl.utcTimeOf(XmlDocument.parse(envelope(dateTime))), DateTime.utc(2026, 10, 21, 9, 30, 5));
      expect(OnvifPtzControl.ptzProfileToken(XmlDocument.parse(envelope(profiles))), 'profile_main');
    });
  });

  group('against a camera on loopback', () {
    late FakeOnvifCamera camera;

    setUp(() async => camera = await FakeOnvifCamera.start());
    tearDown(() => camera.close());

    OnvifPtzControl client() => OnvifPtzControl(host: '127.0.0.1', port: camera.port, credentials: login);

    test('discovers PTZ, then moves and stops on the PTZ profile', () async {
      final ptz = client();
      expect(await ptz.isSupported(), isTrue);
      await ptz.move(PtzDirection.left);
      await ptz.stop();
      ptz.close();

      expect(camera.actions, ['GetSystemDateAndTime', 'GetCapabilities', 'GetProfiles', 'ContinuousMove', 'Stop']);
      final move = camera.bodies[3];
      expect(move, contains('<ProfileToken>profile_main</ProfileToken>'));
      expect(move, contains('x="-0.5" y="0.0"'));
      expect(move, contains('<Username>gate</Username>'));
      expect(move, isNot(contains('secret')), reason: 'only the digest travels');
      expect(camera.bodies[4], contains('<PanTilt>true</PanTilt>'));
    });

    test('a camera without PTZ is reported as unsupported', () async {
      camera.ptz = false;
      final ptz = client();
      expect(await ptz.isSupported(), isFalse);
      await expectLater(ptz.move(PtzDirection.up), throwsA(isA<OnvifException>()));
      ptz.close();
    });

    test('a refused login surfaces the camera\'s fault text', () async {
      camera.rejectLogin = true;
      final ptz = client();
      expect(await ptz.isSupported(), isFalse);
      await expectLater(
        ptz.move(PtzDirection.up),
        throwsA(isA<OnvifException>().having((e) => e.message, 'message', 'Sender not Authorized')),
      );
      ptz.close();
    });
  });
}
