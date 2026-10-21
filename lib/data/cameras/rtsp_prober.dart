import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../domain/cameras/camera_credentials.dart';
import '../../domain/cameras/camera_services.dart';

/// [RtspProber] over a TCP socket: sends `DESCRIBE`, answers a Basic or Digest
/// challenge once, and reads the video codec from the SDP description.
class SocketRtspProber implements RtspProber {
  SocketRtspProber({this.timeout = const Duration(seconds: 5)});

  final Duration timeout;

  @override
  Future<RtspProbeResult> describe(Uri streamUri, CameraCredentials? credentials) async {
    // The request line carries the address without the login.
    final requestUri = Uri(
      scheme: streamUri.scheme,
      host: streamUri.host,
      port: streamUri.hasPort ? streamUri.port : null,
      path: streamUri.path,
      query: streamUri.hasQuery ? streamUri.query : null,
    ).toString();
    final Socket socket;
    try {
      socket = await Socket.connect(streamUri.host, streamUri.hasPort ? streamUri.port : 554, timeout: timeout);
    } on SocketException catch (e) {
      return RtspUnreachable(e.osError?.message ?? e.message);
    } on TimeoutException {
      return RtspUnreachable('No answer within ${timeout.inSeconds} s');
    }

    final reader = _ResponseReader(socket);
    try {
      var response = await _request(socket, reader, requestUri, cseq: 1);
      if (response.status == 401 && credentials != null && credentials.user.isNotEmpty) {
        final authorization = authorizationFor(
          challenges: response.headers['www-authenticate'] ?? const [],
          credentials: credentials,
          method: 'DESCRIBE',
          uri: requestUri,
        );
        if (authorization != null) {
          response = await _request(socket, reader, requestUri, cseq: 2, authorization: authorization);
        }
      }
      return switch (response.status) {
        200 => RtspStreamFound(videoCodec: videoCodecOf(response.body)),
        401 || 403 => const RtspUnauthorized(),
        final status => RtspNotFound(status),
      };
    } on TimeoutException {
      return RtspUnreachable('No answer within ${timeout.inSeconds} s');
    } on Object catch (e) {
      return RtspUnreachable('$e');
    } finally {
      socket.destroy();
      await reader.close();
    }
  }

  Future<_RtspResponse> _request(Socket socket, _ResponseReader reader, String uri, {required int cseq, String? authorization}) {
    socket.write('DESCRIBE $uri RTSP/1.0\r\n'
        'CSeq: $cseq\r\n'
        'Accept: application/sdp\r\n'
        'User-Agent: UniversalRemote\r\n'
        '${authorization == null ? '' : 'Authorization: $authorization\r\n'}'
        '\r\n');
    return reader.next().timeout(timeout);
  }

  /// The `Authorization` value answering [challenges], preferring Digest over Basic;
  /// `null` when no scheme is supported.
  static String? authorizationFor({
    required List<String> challenges,
    required CameraCredentials credentials,
    required String method,
    required String uri,
    String Function()? cnonce,
  }) {
    final digest = challenges.where((c) => c.toLowerCase().startsWith('digest')).firstOrNull;
    if (digest != null) {
      final params = parseChallenge(digest);
      final realm = params['realm'] ?? '';
      final nonce = params['nonce'] ?? '';
      final qop = (params['qop'] ?? '').split(',').map((q) => q.trim()).contains('auth') ? 'auth' : null;
      final clientNonce = qop == null ? null : (cnonce ?? _randomHex)();
      final response = digestResponse(
        user: credentials.user,
        realm: realm,
        password: credentials.password,
        method: method,
        uri: uri,
        nonce: nonce,
        qop: qop,
        nc: '00000001',
        cnonce: clientNonce,
      );
      return [
        'Digest username="${credentials.user}"',
        'realm="$realm"',
        'nonce="$nonce"',
        'uri="$uri"',
        'response="$response"',
        if (params['opaque'] != null) 'opaque="${params['opaque']}"',
        if (qop != null) ...['qop=$qop', 'nc=00000001', 'cnonce="$clientNonce"'],
      ].join(', ');
    }
    if (challenges.any((c) => c.toLowerCase().startsWith('basic'))) {
      return 'Basic ${base64.encode(utf8.encode('${credentials.user}:${credentials.password}'))}';
    }
    return null;
  }

  /// RFC 2617 Digest `response` (MD5; `qop=auth` when [qop] is set).
  static String digestResponse({
    required String user,
    required String realm,
    required String password,
    required String method,
    required String uri,
    required String nonce,
    String? qop,
    String? nc,
    String? cnonce,
  }) {
    final ha1 = _md5('$user:$realm:$password');
    final ha2 = _md5('$method:$uri');
    return qop == null ? _md5('$ha1:$nonce:$ha2') : _md5('$ha1:$nonce:$nc:$cnonce:$qop:$ha2');
  }

  /// `realm="x", nonce="y", qop=auth` → {realm: x, nonce: y, qop: auth}.
  static Map<String, String> parseChallenge(String challenge) {
    final params = <String, String>{};
    for (final match in RegExp(r'(\w+)\s*=\s*(?:"([^"]*)"|([^,\s]+))').allMatches(challenge)) {
      params[match.group(1)!.toLowerCase()] = match.group(2) ?? match.group(3)!;
    }
    return params;
  }

  /// The encoding of the first video track in an SDP description, e.g. `H265`.
  static String? videoCodecOf(String sdp) {
    var inVideo = false;
    for (final line in const LineSplitter().convert(sdp)) {
      if (line.startsWith('m=')) inVideo = line.startsWith('m=video');
      if (inVideo && line.startsWith('a=rtpmap:')) {
        final encoding = line.split(' ').elementAtOrNull(1)?.split('/').first;
        if (encoding != null && encoding.isNotEmpty) return encoding.toUpperCase();
      }
    }
    return null;
  }

  static String _md5(String value) => md5.convert(utf8.encode(value)).toString();

  static String _randomHex() {
    final random = Random.secure();
    return List.generate(8, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}

class _RtspResponse {
  _RtspResponse(this.status, this.headers, this.body);

  final int status;

  /// Lower-case names; a header may repeat (several WWW-Authenticate challenges).
  final Map<String, List<String>> headers;
  final String body;
}

/// Splits the socket's byte stream into RTSP responses (headers + Content-Length body).
class _ResponseReader {
  _ResponseReader(Socket socket) {
    _subscription = socket.listen(_onData, onError: _onError, onDone: _onDone, cancelOnError: true);
  }

  late final StreamSubscription<Uint8List> _subscription;
  final BytesBuilder _buffer = BytesBuilder();
  Completer<_RtspResponse>? _pending;
  Object? _error;

  Future<_RtspResponse> next() {
    final completer = Completer<_RtspResponse>();
    _pending = completer;
    if (_error != null) {
      completer.completeError(_error!);
    } else {
      _tryComplete();
    }
    return completer.future;
  }

  Future<void> close() => _subscription.cancel();

  void _onData(Uint8List data) {
    _buffer.add(data);
    _tryComplete();
  }

  void _onError(Object error) {
    _error = error;
    _pending?.completeError(error);
    _pending = null;
  }

  void _onDone() => _onError(const SocketException('Connection closed by the camera'));

  void _tryComplete() {
    final pending = _pending;
    if (pending == null) return;
    final bytes = _buffer.toBytes();
    final headerEnd = _indexOfHeaderEnd(bytes);
    if (headerEnd < 0) return;
    final head = latin1.decode(bytes.sublist(0, headerEnd));
    final lines = head.split('\r\n');
    final status = int.tryParse(lines.first.split(' ').elementAtOrNull(1) ?? '') ?? 0;
    final headers = <String, List<String>>{};
    for (final line in lines.skip(1)) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      headers.putIfAbsent(line.substring(0, colon).trim().toLowerCase(), () => []).add(line.substring(colon + 1).trim());
    }
    final length = int.tryParse(headers['content-length']?.first ?? '') ?? 0;
    final bodyStart = headerEnd + 4;
    if (bytes.length < bodyStart + length) return;
    final body = utf8.decode(bytes.sublist(bodyStart, bodyStart + length), allowMalformed: true);
    _buffer
      ..clear()
      ..add(bytes.sublist(bodyStart + length));
    _pending = null;
    pending.complete(_RtspResponse(status, headers, body));
  }

  static int _indexOfHeaderEnd(Uint8List bytes) {
    for (var i = 0; i + 3 < bytes.length; i++) {
      if (bytes[i] == 13 && bytes[i + 1] == 10 && bytes[i + 2] == 13 && bytes[i + 3] == 10) return i;
    }
    return -1;
  }
}
