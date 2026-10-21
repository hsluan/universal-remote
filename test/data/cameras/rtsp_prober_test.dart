import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/data/cameras/rtsp_prober.dart';
import 'package:universal_remote/domain/cameras/camera_credentials.dart';
import 'package:universal_remote/domain/cameras/camera_services.dart';

/// A tiny RTSP server on loopback: answers each DESCRIBE with [respond].
class FakeRtspServer {
  FakeRtspServer._(this._server);

  final ServerSocket _server;
  final List<String> requests = [];
  late String Function(String request, int index) respond;

  int get port => _server.port;

  static Future<FakeRtspServer> start() async {
    final server = FakeRtspServer._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));
    server._server.listen((socket) {
      var buffer = '';
      socket.listen((data) {
        buffer += latin1.decode(data);
        while (buffer.contains('\r\n\r\n')) {
          final end = buffer.indexOf('\r\n\r\n') + 4;
          final request = buffer.substring(0, end);
          buffer = buffer.substring(end);
          server.requests.add(request);
          socket.write(server.respond(request, server.requests.length - 1));
        }
      });
    });
    return server;
  }

  Future<void> close() => _server.close();
}

String response(int status, String reason, {Map<String, String> headers = const {}, String body = ''}) {
  final lines = ['RTSP/1.0 $status $reason', 'CSeq: 1', for (final e in headers.entries) '${e.key}: ${e.value}'];
  if (body.isNotEmpty) lines.add('Content-Length: ${utf8.encode(body).length}');
  return '${lines.join('\r\n')}\r\n\r\n$body';
}

const sdp = 'v=0\r\no=- 0 0 IN IP4 0.0.0.0\r\ns=Session\r\n'
    'm=audio 0 RTP/AVP 0\r\na=rtpmap:0 PCMU/8000\r\n'
    'm=video 0 RTP/AVP 96\r\na=rtpmap:96 H265/90000\r\n';

void main() {
  const login = CameraCredentials(user: 'admin', password: 'L2ABCD');

  group('pure helpers', () {
    test('digest response matches the RFC 2617 example', () {
      expect(
        SocketRtspProber.digestResponse(
          user: 'Mufasa',
          realm: 'testrealm@host.com',
          password: 'Circle Of Life',
          method: 'GET',
          uri: '/dir/index.html',
          nonce: 'dcd98b7102dd2f0e8b11d0f600bfb0c093',
          qop: 'auth',
          nc: '00000001',
          cnonce: '0a4f113b',
        ),
        '6629fae49393a05397450978507c4ef1',
      );
    });

    test('parses quoted and bare challenge values', () {
      expect(
        SocketRtspProber.parseChallenge('Digest realm="IP Camera(C2)", nonce="abc", stale=FALSE, algorithm=MD5'),
        {'realm': 'IP Camera(C2)', 'nonce': 'abc', 'stale': 'FALSE', 'algorithm': 'MD5'},
      );
    });

    test('reads the video codec from SDP, skipping audio', () {
      expect(SocketRtspProber.videoCodecOf(sdp), 'H265');
      expect(SocketRtspProber.videoCodecOf('v=0\r\nm=audio 0 RTP/AVP 0\r\na=rtpmap:0 PCMU/8000\r\n'), isNull);
    });

    test('prefers Digest over Basic', () {
      final auth = SocketRtspProber.authorizationFor(
        challenges: ['Basic realm="cam"', 'Digest realm="cam", nonce="n1"'],
        credentials: login,
        method: 'DESCRIBE',
        uri: 'rtsp://h:554/s',
      )!;
      expect(auth, startsWith('Digest username="admin", realm="cam", nonce="n1", uri="rtsp://h:554/s", response="'));
      final basic = SocketRtspProber.authorizationFor(
        challenges: ['Basic realm="cam"'],
        credentials: login,
        method: 'DESCRIBE',
        uri: 'rtsp://h:554/s',
      );
      expect(basic, 'Basic ${base64.encode(utf8.encode('admin:L2ABCD'))}');
    });
  });

  group('against a camera on loopback', () {
    late FakeRtspServer server;

    setUp(() async => server = await FakeRtspServer.start());
    tearDown(() => server.close());

    Uri streamAt(String path) => Uri.parse('rtsp://admin:L2ABCD@127.0.0.1:${server.port}$path');

    test('answers the Digest challenge and reports the codec', () async {
      server.respond = (request, index) => index == 0
          ? response(401, 'Unauthorized', headers: {'WWW-Authenticate': 'Digest realm="Login to cam", nonce="5a1f"'})
          : response(200, 'OK', headers: {'Content-Type': 'application/sdp'}, body: sdp);

      final result = await SocketRtspProber().describe(streamAt('/stream1'), login);

      expect(result, isA<RtspStreamFound>().having((r) => r.videoCodec, 'codec', 'H265'));
      expect(server.requests, hasLength(2));
      final uri = 'rtsp://127.0.0.1:${server.port}/stream1';
      expect(server.requests.first, startsWith('DESCRIBE $uri RTSP/1.0\r\nCSeq: 1\r\n'));
      expect(server.requests.first, isNot(contains('L2ABCD')), reason: 'no password on the request line');
      final expected = SocketRtspProber.digestResponse(
        user: 'admin',
        realm: 'Login to cam',
        password: 'L2ABCD',
        method: 'DESCRIBE',
        uri: uri,
        nonce: '5a1f',
      );
      expect(server.requests.last, contains('CSeq: 2\r\n'));
      expect(server.requests.last, contains('response="$expected"'));
    });

    test('a refused login is unauthorized', () async {
      server.respond = (request, index) =>
          response(401, 'Unauthorized', headers: {'WWW-Authenticate': 'Digest realm="r", nonce="n"'});
      expect(await SocketRtspProber().describe(streamAt('/stream1'), login), isA<RtspUnauthorized>());
    });

    test('a wrong path is not found', () async {
      server.respond = (request, index) => response(404, 'Not Found');
      expect(
        await SocketRtspProber().describe(streamAt('/nope'), login),
        isA<RtspNotFound>().having((r) => r.status, 'status', 404),
      );
    });

    test('a closed port is unreachable', () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      final result = await SocketRtspProber().describe(Uri.parse('rtsp://127.0.0.1:$port/s'), login);
      expect(result, isA<RtspUnreachable>());
    });

    test('a silent camera times out as unreachable', () async {
      server.respond = (request, index) => '';
      final result = await SocketRtspProber(timeout: const Duration(milliseconds: 300)).describe(streamAt('/s'), login);
      expect(result, isA<RtspUnreachable>());
    });
  });
}
