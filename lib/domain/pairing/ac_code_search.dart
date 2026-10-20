import '../encoders/ac/ac_protocol_encoder.dart';

/// State machine for finding which AC code an appliance answers to.
///
/// IR is one-way and the phone has no receiver, so the user is the sensor:
/// each candidate is sent and the user reports whether the AC beeped or turned
/// on. Pure logic; the view model owns timers and transmission.
class AcCodeSearch {
  AcCodeSearch({required List<AcProtocolEncoder> candidates, this.preferredCount = 0})
      : candidates = List.unmodifiable(candidates),
        assert(preferredCount >= 0 && preferredCount <= candidates.length);

  final List<AcProtocolEncoder> candidates;

  /// How many leading candidates are the chosen brand's known codes.
  final int preferredCount;

  int _index = 0;
  AcProtocolEncoder? _match;

  int get index => _index;
  int get total => candidates.length;

  /// 1-based position for display.
  int get position => _index + 1;

  bool get isExhausted => _index >= candidates.length;
  bool get isMatched => _match != null;
  AcProtocolEncoder? get match => _match;

  AcProtocolEncoder get current {
    if (isExhausted) throw StateError('No candidates left');
    return candidates[_index];
  }

  /// Whether the current candidate is one of the brand's known codes.
  bool get isPreferred => _index < preferredCount;

  bool get hasPrevious => _index > 0;

  /// The user saw no response: move to the next candidate.
  void reject() {
    if (isExhausted) return;
    _index++;
  }

  /// Step back, e.g. when the AC answered just before auto-advance moved on.
  void back() {
    if (_index > 0) _index--;
    _match = null;
  }

  /// The user confirmed the current candidate.
  void accept() {
    _match = current;
  }

  /// Undo [accept] and stay on the current candidate.
  void clearMatch() {
    _match = null;
  }

  /// The confirmation step failed: forget the match and continue with the next code.
  void rejectMatch() {
    _match = null;
    reject();
  }

  void restart() {
    _index = 0;
    _match = null;
  }
}
