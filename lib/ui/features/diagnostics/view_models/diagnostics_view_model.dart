import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../domain/encoders/nec_encoder.dart';
import '../../../../domain/encoders/samsung_encoder.dart';
import '../../../../domain/models/ir_packet.dart';
import '../../../../domain/models/ir_send_record.dart';
import '../../../../domain/services/ir_send_log.dart';
import '../../../../domain/use_cases/get_hardware_status_use_case.dart';
import '../../../../domain/use_cases/transmit_ir_packet_use_case.dart';

class DiagnosticsViewModel extends ChangeNotifier {
  DiagnosticsViewModel({
    required this.getHardwareStatusUseCase,
    required this.transmitIrPacketUseCase,
    required this.sendLog,
  }) {
    _logSubscription = sendLog.changes.listen((_) => notifyListeners());
  }

  /// Label of this screen's transmissions in the send log.
  static const String logSource = 'Diagnostics';

  final GetHardwareStatusUseCase getHardwareStatusUseCase;
  final TransmitIrPacketUseCase transmitIrPacketUseCase;

  /// Every transmission of the app (remotes, Find my AC, this screen).
  final IrSendLog sendLog;

  late final StreamSubscription<void> _logSubscription;
  bool _disposed = false;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  HardwareStatus? _status;
  HardwareStatus? get status => _status;

  bool _isTransmitting = false;
  bool get isTransmitting => _isTransmitting;

  String? _lastError;
  String? get lastError => _lastError;

  /// Newest first.
  List<IrSendRecord> get records => sendLog.records;

  Future<void> checkHardware() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      _status = await getHardwareStatusUseCase.execute();
    } catch (e) {
      _lastError = e.toString();
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
      await transmitIrPacketUseCase.execute(packet, source: logSource);
      return true;
    } catch (e) {
      _lastError = e.toString();
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

  void clearLogs() => sendLog.clear();

  /// The send log as plain text, oldest first, for pasting into a bug report.
  String exportLog() => sendLog.export();

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _logSubscription.cancel();
    super.dispose();
  }
}
