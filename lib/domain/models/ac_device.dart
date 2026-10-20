import 'ac_state.dart';

/// A paired air conditioner: which code drives it and the last state sent to it.
class AcDevice {
  const AcDevice({
    required this.id,
    required this.name,
    required this.brandName,
    required this.codeId,
    this.room,
    this.state = const AcState(isPowerOn: false),
  });

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

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'brand': brandName,
        'code': codeId,
        'room': room,
        'state': state.toJson(),
      };

  factory AcDevice.fromJson(Map<String, dynamic> json) {
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
}
