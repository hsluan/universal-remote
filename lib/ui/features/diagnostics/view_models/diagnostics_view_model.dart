import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../domain/encoders/nec_encoder.dart';
import '../../../../domain/encoders/samsung_encoder.dart';
import '../../../../domain/models/ir_packet.dart';
import '../../../../domain/use_cases/get_hardware_status_use_case.dart';
import '../../../../domain/use_cases/transmit_ir_packet_use_case.dart';

class DiagnosticsViewModel extends ChangeNotifier {
  DiagnosticsViewModel({
    required this.getHardwareStatusUseCase,
    required this.transmitIrPacketUseCase,
  });

  final GetHardwareStatusUseCase getHardwareStatusUseCase;
  final TransmitIrPacketUseCase transmitIrPacketUseCase;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  HardwareStatus? _status;
  HardwareStatus? get status => _status;

  bool _isTransmitting = false;
  bool get isTransmitting => _isTransmitting;

  String? _lastError;
  String? get lastError => _lastError;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  Future<void> checkHardware() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      _status = await getHardwareStatusUseCase.execute();
      _addLog('Hardware check: hasEmitter=${_status?.hasEmitter}, ranges=${_status?.frequencies.length}');
    } catch (e) {
      _lastError = e.toString();
      _addLog('Hardware check error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> transmit(IrPacket packet) async {
    _isTransmitting = true;
    _lastError = null;
    notifyListeners();

    try {
      HapticFeedback.mediumImpact().ignore();
      await transmitIrPacketUseCase.execute(packet);
      _addLog('Transmitted: ${packet.name} (${packet.pattern.length} pulses, ${packet.frequency} Hz)');
      return true;
    } catch (e) {
      _lastError = e.toString();
      _addLog('Transmission failed: $e');
      return false;
    } finally {
      // Keep transmitting state active briefly for visual feedback
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _isTransmitting = false;
      notifyListeners();
    }
  }

  Future<bool> transmitSamsungPower() {
    final packet = SamsungEncoder.tvPower().encode();
    return transmit(packet);
  }

  Future<bool> transmitLgPower() {
    final packet = NecEncoder.lgTvPower().encode();
    return transmit(packet);
  }

  Future<bool> transmitCustomNec({required int address, required int command}) {
    final packet = NecEncoder.standard(
      address: address,
      command: command,
      name: 'NEC (0x${address.toRadixString(16).padLeft(2, '0')}, 0x${command.toRadixString(16).padLeft(2, '0')})',
    ).encode();
    return transmit(packet);
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void _addLog(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(0, '[$time] $message');
    if (_logs.length > 50) {
      _logs.removeLast();
    }
  }
}
