import 'ac_protocol_encoder.dart';

/// Registry of the AC encoders the app ships, looked up by persisted id.
class AcEncoderRegistry {
  /// [encoders] order is the search order when the brand is unknown, so list
  /// the most common protocols first.
  AcEncoderRegistry(List<AcProtocolEncoder> encoders)
      : all = List.unmodifiable(encoders),
        _byId = {for (final encoder in encoders) encoder.id: encoder} {
    assert(_byId.length == encoders.length, 'AC encoder ids must be unique');
  }

  final List<AcProtocolEncoder> all;
  final Map<String, AcProtocolEncoder> _byId;

  AcProtocolEncoder? find(String id) => _byId[id];

  AcProtocolEncoder require(String id) {
    final encoder = _byId[id];
    if (encoder == null) throw StateError('Unknown AC code "$id"');
    return encoder;
  }

  /// Candidates to try for a brand: its known codes first, then every other code.
  List<AcProtocolEncoder> candidatesFor(List<String> preferredIds) {
    final preferred = [for (final id in preferredIds) ?_byId[id]];
    final preferredSet = preferred.toSet();
    return [...preferred, ...all.where((e) => !preferredSet.contains(e))];
  }
}
