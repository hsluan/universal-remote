import '../models/ac_state.dart';
import 'device_connection.dart';
import 'device_kind.dart';
import 'device_state.dart';

export 'device_connection.dart';
export 'device_kind.dart';
export 'device_state.dart';

/// Any controllable thing at home: what it is ([kind]), how the app reaches it
/// ([connection]) and what it last knew about it ([state]).
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.kind,
    required this.connection,
    this.brandName = '',
    this.room,
    this.state,
  });

  final String id;
  final String name;
  final DeviceKind kind;
  final DeviceConnection connection;
  final String brandName;
  final String? room;

  /// For one-way connections (IR) this is the state last sent; otherwise the last one reported.
  final DeviceState? state;

  Device copyWith({String? name, String? room, DeviceConnection? connection, DeviceState? state}) {
    return Device(
      id: id,
      name: name ?? this.name,
      kind: kind,
      connection: connection ?? this.connection,
      brandName: brandName,
      room: room ?? this.room,
      state: state ?? this.state,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'brand': brandName,
        'room': room,
        'connection': connection.toJson(),
        if (state != null) 'state': state!.toJson(),
      };

  /// Reads a device written by [toJson]; throws [FormatException] for an unknown kind.
  factory Device.fromJson(Map<String, dynamic> json) {
    final kind = DeviceKind.fromName(json['kind']);
    if (kind == null) throw FormatException('Unknown device kind "${json['kind']}"');
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: kind,
      connection: DeviceConnection.fromJson(json['connection'] as Map<String, dynamic>),
      brandName: json['brand'] as String? ?? '',
      room: json['room'] as String?,
      state: _stateFromJson(kind, json['state']),
    );
  }

  static DeviceState? _stateFromJson(DeviceKind kind, Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return switch (kind) {
      DeviceKind.airConditioner => AcState.fromJson(json),
      _ => RawDeviceState(json),
    };
  }

  @override
  String toString() => 'Device($id, ${kind.name}, ${connection.runtimeType})';
}
