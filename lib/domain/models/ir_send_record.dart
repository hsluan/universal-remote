/// One IR transmission, kept by `IrSendLog` for field debugging.
class IrSendRecord {
  const IrSendRecord({
    required this.time,
    required this.source,
    required this.description,
    required this.frequency,
    required this.pulses,
    required this.patternMicros,
    required this.elapsed,
    this.frameHex,
    this.error,
  });

  final DateTime time;

  /// Who sent it: a device name, "Find my AC", "Diagnostics".
  final String source;

  /// What was sent, e.g. "Midea on + swing toggle · AcState(on, cool, 25°C, fan auto)".
  final String description;

  /// The protocol's state bytes, when the code has a byte frame.
  final String? frameHex;

  final int frequency;
  final int pulses;

  /// Length of the emitted pattern.
  final int patternMicros;

  /// Wall time of the platform call (pattern length plus driver overhead).
  final Duration elapsed;

  /// Why the transmission failed; `null` when it went out.
  final String? error;

  bool get ok => error == null;

  /// One plain-text line, for copying the log into a bug report.
  String toLogLine() {
    final clock = time.toIso8601String().substring(11, 23);
    final status = ok ? 'ok' : 'FAILED: $error';
    final frame = frameHex == null ? '' : ' [$frameHex]';
    return '$clock $source: $description$frame · $frequency Hz, $pulses pulses, '
        '${(patternMicros / 1000).toStringAsFixed(0)} ms pattern, ${elapsed.inMilliseconds} ms call · $status';
  }
}
