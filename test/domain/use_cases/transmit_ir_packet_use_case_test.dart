import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/midea_ac_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';
import 'package:universal_remote/domain/models/ir_packet.dart';
import 'package:universal_remote/domain/models/ir_send_record.dart';
import 'package:universal_remote/domain/services/ir_send_log.dart';
import 'package:universal_remote/domain/use_cases/transmit_ac_state_use_case.dart';
import 'package:universal_remote/domain/use_cases/transmit_ir_packet_use_case.dart';

import '../../helpers/fakes.dart';

void main() {
  const packet = IrPacket(frequency: 38000, pattern: [9000, 4500, 560], name: 'Test burst');

  group('TransmitIrPacketUseCase', () {
    test('records sent and failed transmissions, newest first', () async {
      final transmitter = FakeTransmitter();
      final log = IrSendLog();
      final useCase = TransmitIrPacketUseCase(transmitter: transmitter, log: log);

      await useCase.execute(packet, source: 'Diagnostics', frameHex: 'aa bb');
      transmitter.failWithCode = 'NO_IR_EMITTER';
      await expectLater(useCase.execute(packet, source: 'Bedroom AC'), throwsA(isA<PlatformException>()));

      final records = log.records;
      expect(records, hasLength(2));
      expect(records.first.source, 'Bedroom AC');
      expect(records.first.ok, isFalse);
      expect(records.first.error, contains('NO_IR_EMITTER'));
      expect(records.last.ok, isTrue);
      expect(records.last.description, 'Test burst');
      expect(records.last.frameHex, 'aa bb');
      expect(records.last.pulses, 3);
      expect(records.last.patternMicros, 14060);
    });

    test('rejects a pattern over the platform limit without transmitting, and logs it', () async {
      final transmitter = FakeTransmitter();
      final log = IrSendLog();
      const tooLong = IrPacket(frequency: 38000, pattern: [1500000, 600000, 100]);

      await expectLater(
        TransmitIrPacketUseCase(transmitter: transmitter, log: log).execute(tooLong),
        throwsArgumentError,
      );
      expect(transmitter.sent, isEmpty);
      expect(log.records.single.ok, isFalse);
    });
  });

  group('TransmitAcStateUseCase', () {
    test('logs the readable state and the protocol frame', () async {
      final log = IrSendLog();
      final useCase = TransmitAcStateUseCase(
        transmitPacket: TransmitIrPacketUseCase(transmitter: FakeTransmitter(), log: log),
      );
      const state = AcState(mode: AcMode.cool, temperature: 17, fanSpeed: AcFanSpeed.low);

      await useCase.execute(const MideaAcEncoder(), state, previous: state.copyWith(swingVertical: true), source: 'Living AC');

      final record = log.records.single;
      expect(record.source, 'Living AC');
      expect(record.description, 'Midea on + swing toggle · $state');
      expect(record.frameHex, 'a1 88 40 ff ff 56');
    });
  });

  group('IrSendLog', () {
    IrSendRecord record(int i) => IrSendRecord(
          time: DateTime(2026, 10, 20, 21, 0, i),
          source: 'S$i',
          description: 'D$i',
          frequency: 38000,
          pulses: 67,
          patternMicros: 67500,
          elapsed: const Duration(milliseconds: 80),
        );

    test('keeps the newest records up to its capacity and notifies changes', () async {
      final log = IrSendLog(capacity: 3);
      var changes = 0;
      final subscription = log.changes.listen((_) => changes++);
      for (var i = 0; i < 5; i++) {
        log.add(record(i));
      }
      await pumpEventQueue();
      expect(log.records.map((r) => r.source), ['S4', 'S3', 'S2']);
      log.clear();
      await pumpEventQueue();
      expect(log.records, isEmpty);
      expect(changes, 6);
      await subscription.cancel();
    });

    test('exports one line per record, oldest first', () {
      final log = IrSendLog()
        ..add(record(1))
        ..add(record(2));
      final lines = log.export().split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, startsWith('21:00:01.000 S1: D1'));
      expect(lines.first, endsWith('38000 Hz, 67 pulses, 68 ms pattern, 80 ms call · ok'));
    });
  });
}
