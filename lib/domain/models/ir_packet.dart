/// Represents an encoded IR signal ready for transmission by the hardware emitter.
class IrPacket {
  const IrPacket({
    required this.frequency,
    required this.pattern,
    this.name = 'IR Packet',
  });

  /// Carrier frequency in Hertz (typically 38000 for consumer appliances).
  final int frequency;

  /// Alternating mark (on) and space (off) intervals in microseconds.
  final List<int> pattern;

  /// Optional debug or descriptive label.
  final String name;

  /// Total duration of the transmission burst in microseconds.
  int get totalDurationMicros => pattern.fold(0, (sum, val) => sum + val);

  @override
  String toString() => '$name ($frequency Hz, ${pattern.length} pulses, ${(totalDurationMicros / 1000).toStringAsFixed(1)} ms)';
}
