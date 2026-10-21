import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:xml/xml.dart';

import '../../domain/cameras/camera_services.dart';
import '../services/multicast_lock.dart';

/// [CameraDiscovery] with ONVIF WS-Discovery: a SOAP Probe for network video
/// transmitters, multicast to 239.255.255.250:3702; cameras answer the sender directly.
class WsDiscovery implements CameraDiscovery {
  WsDiscovery({InternetAddress? target, this.port = 3702, this.multicastLock})
      : target = target ?? InternetAddress('239.255.255.250');

  final InternetAddress target;
  final int port;

  /// Lets Wi-Fi deliver multicast while searching (Android drops it to save battery).
  final MulticastLock? multicastLock;

  @override
  Stream<DiscoveredCamera> discover({Duration timeout = const Duration(seconds: 3)}) {
    final controller = StreamController<DiscoveredCamera>();
    RawDatagramSocket? socket;
    Timer? timer;
    final seen = <String>{};
    var finished = false;

    // Runs once: on timeout, or when the listener cancels (closing triggers it too).
    Future<void> finish() async {
      if (finished) return;
      finished = true;
      timer?.cancel();
      socket?.close();
      await multicastLock?.release();
      if (!controller.isClosed) await controller.close();
    }

    Future<void> start() async {
      try {
        await multicastLock?.acquire();
        final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        socket = s;
        s.listen((event) {
          if (event != RawSocketEvent.read) return;
          final datagram = s.receive();
          if (datagram == null) return;
          for (final camera in parseProbeMatches(utf8.decode(datagram.data, allowMalformed: true), datagram.address)) {
            if (seen.add('${camera.host}:${camera.onvifPort}')) controller.add(camera);
          }
        });
        final probe = utf8.encode(probeMessage(_uuid()));
        // UDP may drop a datagram: send the probe twice.
        s.send(probe, target, port);
        Timer(const Duration(milliseconds: 300), () => socket?.send(probe, target, port));
        timer = Timer(timeout, finish);
      } on Object catch (e) {
        if (!controller.isClosed) controller.addError(e);
        await finish();
      }
    }

    controller.onListen = start;
    controller.onCancel = finish;
    return controller.stream;
  }

  /// A WS-Discovery Probe for ONVIF network video transmitters.
  static String probeMessage(String messageId) =>
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope" '
      'xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing" '
      'xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery" '
      'xmlns:dn="http://www.onvif.org/ver10/network/wsdl">'
      '<e:Header><w:MessageID>uuid:$messageId</w:MessageID>'
      '<w:To e:mustUnderstand="true">urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>'
      '<w:Action e:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>'
      '</e:Header><e:Body><d:Probe><d:Types>dn:NetworkVideoTransmitter</d:Types></d:Probe></e:Body></e:Envelope>';

  /// Cameras in a ProbeMatches answer. The host and port come from the first IPv4
  /// device-service address, else from [sender] on port 80; name and hardware from
  /// the ONVIF scopes.
  static List<DiscoveredCamera> parseProbeMatches(String xml, InternetAddress sender) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException {
      return const [];
    }
    return [
      for (final match in document.findAllElements('ProbeMatch', namespaceUri: '*'))
        _cameraFrom(match, sender),
    ];
  }

  static DiscoveredCamera _cameraFrom(XmlElement match, InternetAddress sender) {
    final addresses = (match.findAllElements('XAddrs', namespaceUri: '*').firstOrNull?.innerText ?? '')
        .split(RegExp(r'\s+'))
        .map(Uri.tryParse)
        .whereType<Uri>()
        .where((uri) => uri.host.isNotEmpty);
    final ipv4 = addresses.where((uri) => InternetAddress.tryParse(uri.host)?.type == InternetAddressType.IPv4).firstOrNull;
    final scopes = (match.findAllElements('Scopes', namespaceUri: '*').firstOrNull?.innerText ?? '').split(RegExp(r'\s+'));
    String? scope(String key) {
      const prefix = 'onvif://www.onvif.org/';
      for (final s in scopes) {
        if (s.startsWith('$prefix$key/')) return Uri.decodeComponent(s.substring(prefix.length + key.length + 1));
      }
      return null;
    }

    return DiscoveredCamera(
      host: ipv4?.host ?? sender.address,
      onvifPort: ipv4 != null && ipv4.hasPort ? ipv4.port : 80,
      name: scope('name'),
      hardware: scope('hardware'),
    );
  }

  static String _uuid() {
    final r = Random.secure();
    String hex(int bytes) => List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return '${hex(4)}-${hex(2)}-${hex(2)}-${hex(2)}-${hex(6)}';
  }
}
