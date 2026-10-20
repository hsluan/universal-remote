/// Mark/space durations (microseconds) of the two bit symbols of a pulse-distance
/// or pulse-width protocol.
class BitTiming {
  const BitTiming({
    required this.oneMark,
    required this.oneSpace,
    required this.zeroMark,
    required this.zeroSpace,
  });

  /// Pulse-distance coding: both symbols share [mark], the space length carries the bit.
  const BitTiming.pulseDistance({
    required int mark,
    required this.oneSpace,
    required this.zeroSpace,
  })  : oneMark = mark,
        zeroMark = mark;

  final int oneMark;
  final int oneSpace;
  final int zeroMark;
  final int zeroSpace;
}

/// Builder for the alternating mark/space pattern that `ConsumerIrManager` emits.
///
/// Consecutive intervals of the same kind are merged, so a bit's trailing space
/// and the following gap become one space. A leading space is dropped (the
/// pattern must start with a mark) and [build] drops a trailing space, which
/// carries no signal.
class PulseTrain {
  final List<int> _pattern = [];

  bool get _endsWithMark => _pattern.length.isOdd;

  /// Sum of all intervals added so far, in microseconds.
  int get durationMicros => _pattern.fold(0, (sum, value) => sum + value);

  void mark(int micros) {
    if (micros <= 0) return;
    if (_endsWithMark) {
      _pattern[_pattern.length - 1] += micros;
    } else {
      _pattern.add(micros);
    }
  }

  void space(int micros) {
    if (micros <= 0 || _pattern.isEmpty) return;
    if (_endsWithMark) {
      _pattern.add(micros);
    } else {
      _pattern[_pattern.length - 1] += micros;
    }
  }

  /// Appends the lowest [count] bits of [value].
  void bits(int value, int count, BitTiming timing, {bool msbFirst = false}) {
    for (var i = 0; i < count; i++) {
      final shift = msbFirst ? count - 1 - i : i;
      if (((value >> shift) & 1) == 1) {
        mark(timing.oneMark);
        space(timing.oneSpace);
      } else {
        mark(timing.zeroMark);
        space(timing.zeroSpace);
      }
    }
  }

  /// Appends whole bytes in order, each byte's bits LSB first unless [msbFirst].
  void bytes(Iterable<int> values, BitTiming timing, {bool msbFirst = false}) {
    for (final value in values) {
      bits(value & 0xFF, 8, timing, msbFirst: msbFirst);
    }
  }

  List<int> build() {
    final end = _endsWithMark ? _pattern.length : _pattern.length - 1;
    return List.unmodifiable(_pattern.sublist(0, end < 0 ? 0 : end));
  }
}
