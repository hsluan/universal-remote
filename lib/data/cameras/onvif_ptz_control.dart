import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import '../../domain/cameras/camera_credentials.dart';
import '../../domain/cameras/camera_services.dart';

/// An ONVIF error, with the camera's fault text when it sent one.
class OnvifException implements Exception {
  OnvifException(this.message);

  final String message;

  @override
  String toString() => 'OnvifException: $message';
}

/// [PtzControl] over ONVIF SOAP: device service → capabilities → media profile → PTZ.
///
/// Authenticates with a WS-Security UsernameToken digest, timed with the camera's own
/// clock (cameras reject tokens that look too old), and answers HTTP Basic/Digest
/// challenges as well, since cameras differ in which one they check.
class OnvifPtzControl implements PtzControl {
  OnvifPtzControl({
    required this.host,
    required this.port,
    required this.credentials,
    HttpClient? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? HttpClient() {
    _client.authenticate = (url, scheme, realm) async {
      final credential = scheme.toLowerCase() == 'digest'
          ? HttpClientDigestCredentials(credentials.user, credentials.password)
          : HttpClientBasicCredentials(credentials.user, credentials.password);
      _client.addCredentials(url, realm ?? '', credential);
      return true;
    };
  }

  final String host;
  final int port;
  final CameraCredentials credentials;
  final Duration timeout;
  final HttpClient _client;

  /// Velocity used for moves, in ONVIF's normalized -1..1 space.
  static const double speed = 0.5;

  Duration _clockOffset = Duration.zero;
  Uri? _ptzUri;
  String? _profileToken;
  Future<void>? _prepared;

  Uri get deviceServiceUri => Uri(scheme: 'http', host: host, port: port, path: '/onvif/device_service');

  @override
  Future<bool> isSupported() async {
    try {
      await _prepare();
      return _ptzUri != null && _profileToken != null;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> move(PtzDirection direction) async {
    await _prepare();
    final ptz = _requirePtz();
    await _call(
      ptz,
      'http://www.onvif.org/ver20/ptz/wsdl/ContinuousMove',
      '<ContinuousMove xmlns="http://www.onvif.org/ver20/ptz/wsdl">'
          '<ProfileToken>${_escape(_profileToken!)}</ProfileToken>'
          '<Velocity><PanTilt xmlns="http://www.onvif.org/ver10/schema" '
          'x="${direction.pan * speed}" y="${direction.tilt * speed}"/></Velocity>'
          '</ContinuousMove>',
    );
  }

  @override
  Future<void> stop() async {
    await _prepare();
    final ptz = _requirePtz();
    await _call(
      ptz,
      'http://www.onvif.org/ver20/ptz/wsdl/Stop',
      '<Stop xmlns="http://www.onvif.org/ver20/ptz/wsdl">'
          '<ProfileToken>${_escape(_profileToken!)}</ProfileToken>'
          '<PanTilt>true</PanTilt><Zoom>false</Zoom>'
          '</Stop>',
    );
  }

  void close() => _client.close(force: true);

  Uri _requirePtz() {
    final ptz = _ptzUri;
    if (ptz == null || _profileToken == null) throw OnvifException('This camera has no ONVIF pan/tilt');
    return ptz;
  }

  Future<void> _prepare() => _prepared ??= _discoverServices().catchError((Object e) {
        // Let a later call try again (the camera may have been offline).
        _prepared = null;
        throw e;
      });

  Future<void> _discoverServices() async {
    await _syncClock();
    final capabilities = await _call(
      deviceServiceUri,
      'http://www.onvif.org/ver10/device/wsdl/GetCapabilities',
      '<GetCapabilities xmlns="http://www.onvif.org/ver10/device/wsdl"><Category>All</Category></GetCapabilities>',
    );
    final media = _serviceAddress(capabilities, 'Media');
    _ptzUri = _serviceAddress(capabilities, 'PTZ');
    if (media == null || _ptzUri == null) return;

    final profiles = await _call(
      media,
      'http://www.onvif.org/ver10/media/wsdl/GetProfiles',
      '<GetProfiles xmlns="http://www.onvif.org/ver10/media/wsdl"/>',
    );
    _profileToken = ptzProfileToken(profiles);
  }

  /// Reads the camera's UTC clock (no login needed) to time the UsernameToken.
  Future<void> _syncClock() async {
    try {
      final response = await _call(
        deviceServiceUri,
        'http://www.onvif.org/ver10/device/wsdl/GetSystemDateAndTime',
        '<GetSystemDateAndTime xmlns="http://www.onvif.org/ver10/device/wsdl"/>',
        authenticate: false,
      );
      final cameraTime = utcTimeOf(response);
      if (cameraTime != null) _clockOffset = cameraTime.difference(DateTime.now().toUtc());
    } on Object {
      _clockOffset = Duration.zero;
    }
  }

  Future<XmlDocument> _call(Uri uri, String action, String body, {bool authenticate = true}) async {
    final envelope = soapEnvelope(
      body,
      security: authenticate
          ? usernameToken(
              user: credentials.user,
              password: credentials.password,
              nonce: _randomNonce(),
              created: DateTime.now().toUtc().add(_clockOffset),
            )
          : null,
    );
    final request = await _client.postUrl(uri).timeout(timeout);
    request.headers.contentType = ContentType('application', 'soap+xml', charset: 'utf-8', parameters: {'action': action});
    request.add(utf8.encode(envelope));
    final response = await request.close().timeout(timeout);
    final text = await response.transform(utf8.decoder).join().timeout(timeout);
    XmlDocument document;
    try {
      document = XmlDocument.parse(text);
    } on XmlException {
      throw OnvifException('HTTP ${response.statusCode} from $uri');
    }
    final fault = document.findAllElements('Fault', namespaceUri: '*').firstOrNull;
    if (fault != null || response.statusCode >= 400) {
      final reason = fault?.findAllElements('Text', namespaceUri: '*').firstOrNull?.innerText.trim();
      throw OnvifException(reason == null || reason.isEmpty ? 'HTTP ${response.statusCode} from $uri' : reason);
    }
    return document;
  }

  /// The path of a capability's service at the address this client was given.
  ///
  /// Cameras often report an internal host name or address (and sometimes a port
  /// that only works inside their own network) in these entries, while their ONVIF
  /// services share one HTTP endpoint: keep the path, use the configured host and port.
  Uri? _serviceAddress(XmlDocument capabilities, String category) {
    final element = capabilities.findAllElements(category, namespaceUri: '*').firstOrNull;
    final address = element?.findAllElements('XAddr', namespaceUri: '*').firstOrNull?.innerText.trim();
    if (address == null || address.isEmpty) return null;
    final parsed = Uri.tryParse(address);
    if (parsed == null) return null;
    return parsed.replace(scheme: 'http', host: host, port: port);
  }

  // ---------------------------------------------------------- Pure helpers

  /// The token of the first media profile with a PTZ configuration, else the first profile.
  static String? ptzProfileToken(XmlDocument profiles) {
    final all = profiles.findAllElements('Profiles', namespaceUri: '*').toList();
    final withPtz = all.where((p) => p.findAllElements('PTZConfiguration', namespaceUri: '*').isNotEmpty);
    return (withPtz.firstOrNull ?? all.firstOrNull)?.getAttribute('token');
  }

  /// The camera's UTC time from a GetSystemDateAndTime response.
  static DateTime? utcTimeOf(XmlDocument response) {
    final utc = response.findAllElements('UTCDateTime', namespaceUri: '*').firstOrNull;
    if (utc == null) return null;
    int? part(String name) => int.tryParse(utc.findAllElements(name, namespaceUri: '*').firstOrNull?.innerText.trim() ?? '');
    final year = part('Year');
    final month = part('Month');
    final day = part('Day');
    if (year == null || month == null || day == null) return null;
    return DateTime.utc(year, month, day, part('Hour') ?? 0, part('Minute') ?? 0, part('Second') ?? 0);
  }

  /// WS-Security UsernameToken with `PasswordDigest = Base64(SHA1(nonce + created + password))`.
  static String usernameToken({
    required String user,
    required String password,
    required List<int> nonce,
    required DateTime created,
  }) {
    final createdText = _isoSeconds(created);
    final digest = base64.encode(sha1.convert([...nonce, ...utf8.encode(createdText), ...utf8.encode(password)]).bytes);
    return '<Security s:mustUnderstand="1" '
        'xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">'
        '<UsernameToken><Username>${_escape(user)}</Username>'
        '<Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">'
        '$digest</Password>'
        '<Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">'
        '${base64.encode(nonce)}</Nonce>'
        '<Created xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">'
        '$createdText</Created></UsernameToken></Security>';
  }

  static String soapEnvelope(String body, {String? security}) =>
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">'
      '${security == null ? '' : '<s:Header>$security</s:Header>'}'
      '<s:Body>$body</s:Body></s:Envelope>';

  /// `2010-09-16T07:50:45Z`: UTC, whole seconds, as the UsernameToken profile examples use.
  static String _isoSeconds(DateTime time) {
    final utc = time.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}'
        'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
  }

  static List<int> _randomNonce() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256));
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
