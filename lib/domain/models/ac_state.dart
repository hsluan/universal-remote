import '../devices/device_state.dart';

enum AcMode { auto, cool, dry, fan, heat }

enum AcFanSpeed { auto, low, medium, high }

/// Full desired state of an air conditioner.
///
/// AC remotes are stateful: every button press re-sends the whole state, so the
/// app keeps the last state per device and sends a new copy on each change.
class AcState implements DeviceState {
  const AcState({
    this.isPowerOn = true,
    this.mode = AcMode.cool,
    this.temperature = 25,
    this.fanSpeed = AcFanSpeed.auto,
    this.swingVertical = false,
    this.swingHorizontal = false,
    this.turbo = false,
  });

  /// The frame sent while searching for a matching code: on, cool, 25 °C, auto fan.
  static const AcState probe = AcState();

  final bool isPowerOn;
  final AcMode mode;

  /// Target temperature in whole degrees Celsius.
  final int temperature;

  final AcFanSpeed fanSpeed;
  final bool swingVertical;
  final bool swingHorizontal;

  /// Powerful / turbo boost, when the protocol supports it.
  final bool turbo;

  AcState copyWith({
    bool? isPowerOn,
    AcMode? mode,
    int? temperature,
    AcFanSpeed? fanSpeed,
    bool? swingVertical,
    bool? swingHorizontal,
    bool? turbo,
  }) {
    return AcState(
      isPowerOn: isPowerOn ?? this.isPowerOn,
      mode: mode ?? this.mode,
      temperature: temperature ?? this.temperature,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      swingVertical: swingVertical ?? this.swingVertical,
      swingHorizontal: swingHorizontal ?? this.swingHorizontal,
      turbo: turbo ?? this.turbo,
    );
  }

  @override
  Map<String, Object?> toJson() => {
        'power': isPowerOn,
        'mode': mode.name,
        'temperature': temperature,
        'fan': fanSpeed.name,
        'swingV': swingVertical,
        'swingH': swingHorizontal,
        'turbo': turbo,
      };

  /// Reads a state written by [toJson]; unknown or missing fields keep their defaults.
  factory AcState.fromJson(Map<String, dynamic> json) {
    const fallback = AcState();
    return AcState(
      isPowerOn: json['power'] as bool? ?? fallback.isPowerOn,
      mode: AcMode.values.asNameMap()[json['mode']] ?? fallback.mode,
      temperature: (json['temperature'] as num?)?.toInt() ?? fallback.temperature,
      fanSpeed: AcFanSpeed.values.asNameMap()[json['fan']] ?? fallback.fanSpeed,
      swingVertical: json['swingV'] as bool? ?? fallback.swingVertical,
      swingHorizontal: json['swingH'] as bool? ?? fallback.swingHorizontal,
      turbo: json['turbo'] as bool? ?? fallback.turbo,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AcState &&
      other.isPowerOn == isPowerOn &&
      other.mode == mode &&
      other.temperature == temperature &&
      other.fanSpeed == fanSpeed &&
      other.swingVertical == swingVertical &&
      other.swingHorizontal == swingHorizontal &&
      other.turbo == turbo;

  @override
  int get hashCode => Object.hash(isPowerOn, mode, temperature, fanSpeed, swingVertical, swingHorizontal, turbo);

  @override
  String toString() => 'AcState(${isPowerOn ? 'on' : 'off'}, ${mode.name}, $temperature°C, fan ${fanSpeed.name}'
      '${swingVertical ? ', swingV' : ''}${swingHorizontal ? ', swingH' : ''}${turbo ? ', turbo' : ''})';
}
