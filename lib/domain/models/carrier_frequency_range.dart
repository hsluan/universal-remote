/// Represents a carrier frequency range supported by the device's IR transmitter.
class CarrierFrequencyRange {
  const CarrierFrequencyRange({
    required this.minFrequency,
    required this.maxFrequency,
  });

  final int minFrequency;
  final int maxFrequency;

  factory CarrierFrequencyRange.fromMap(Map<dynamic, dynamic> map) {
    return CarrierFrequencyRange(
      minFrequency: (map['minFrequency'] as num).toInt(),
      maxFrequency: (map['maxFrequency'] as num).toInt(),
    );
  }

  @override
  String toString() => '${(minFrequency / 1000).toStringAsFixed(1)} kHz - ${(maxFrequency / 1000).toStringAsFixed(1)} kHz';
}
