/// Last known state of a device. Each kind has its own type (e.g. `AcState`).
abstract interface class DeviceState {
  Map<String, Object?> toJson();
}

/// State of a kind this version cannot read yet; kept as written.
final class RawDeviceState implements DeviceState {
  const RawDeviceState(this.json);

  final Map<String, Object?> json;

  @override
  Map<String, Object?> toJson() => json;
}
