import '../devices/device.dart';
import 'ac_state.dart';

/// An air conditioner paired with an IR code: the typed view of a [Device] that the
/// AC screens and the send queue work with.
class AcDevice {
  const AcDevice({
    required this.id,
    required this.name,
    required this.brandName,
    required this.codeId,
    this.room,
    this.state = const AcState(isPowerOn: false),
  });

  /// Views [device] as an AC; throws [ArgumentError] unless [isAc] holds.
  factory AcDevice.fromDevice(Device device) {
    final connection = device.connection;
    if (device.kind != DeviceKind.airConditioner || connection is! IrConnection) {
      throw ArgumentError.value(device.id, 'device', 'is not an IR air conditioner');
    }
    final state = device.state;
    return AcDevice(
      id: device.id,
      name: device.name,
      brandName: device.brandName,
      codeId: connection.codeId,
      room: device.room,
      state: state is AcState ? state : const AcState(isPowerOn: false),
    );
  }

  /// Reads the version 1 storage format (`ac_devices.v1`), kept for migration.
  factory AcDevice.fromLegacyJson(Map<String, dynamic> json) {
    return AcDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      brandName: json['brand'] as String? ?? '',
      codeId: json['code'] as String,
      room: json['room'] as String?,
      state: json['state'] is Map<String, dynamic>
          ? AcState.fromJson(json['state'] as Map<String, dynamic>)
          : const AcState(isPowerOn: false),
    );
  }

  /// Whether [device] is an air conditioner driven by IR codes.
  static bool isAc(Device device) => device.kind == DeviceKind.airConditioner && device.connection is IrConnection;

  final String id;
  final String name;
  final String brandName;

  /// Id of the `AcProtocolEncoder` found during pairing.
  final String codeId;

  final String? room;
  final AcState state;

  AcDevice copyWith({String? name, String? room, AcState? state, String? codeId}) {
    return AcDevice(
      id: id,
      name: name ?? this.name,
      brandName: brandName,
      codeId: codeId ?? this.codeId,
      room: room ?? this.room,
      state: state ?? this.state,
    );
  }

  Device toDevice() => Device(
        id: id,
        name: name,
        kind: DeviceKind.airConditioner,
        connection: IrConnection(codeId: codeId),
        brandName: brandName,
        room: room,
        state: state,
      );
}
