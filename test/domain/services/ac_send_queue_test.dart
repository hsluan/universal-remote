import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/standard_ac_encoders.dart';
import 'package:universal_remote/domain/models/ac_device.dart';
import 'package:universal_remote/domain/models/ac_state.dart';
import 'package:universal_remote/domain/services/ac_send_queue.dart';
import 'package:universal_remote/domain/services/ir_send_log.dart';
import 'package:universal_remote/domain/use_cases/transmit_ac_state_use_case.dart';
import 'package:universal_remote/domain/use_cases/transmit_ir_packet_use_case.dart';

import '../../helpers/fakes.dart';

void main() {
  const midea = AcDevice(id: 'm', name: 'Living AC', brandName: 'Midea', codeId: 'midea', state: AcState());
  const coolix = AcDevice(id: 'c', name: 'Bedroom AC', brandName: 'Beko', codeId: 'coolix', state: AcState());

  late FakeTransmitter transmitter;
  late InMemoryDeviceRepository repository;
  late IrSendLog log;
  late AcSendQueue queue;

  AcSendQueue createQueue() => AcSendQueue(
        registry: createStandardAcRegistry(),
        transmitAcState: TransmitAcStateUseCase(
          transmitPacket: TransmitIrPacketUseCase(transmitter: transmitter, log: log),
        ),
        repository: repository,
      );

  setUp(() {
    transmitter = FakeTransmitter();
    repository = InMemoryDeviceRepository([midea.toDevice(), coolix.toDevice()]);
    log = IrSendLog();
    queue = createQueue();
  });

  /// Keeps transmissions in flight until the returned gate completes.
  Completer<void> holdTransmissions() {
    final gate = Completer<void>();
    transmitter.onTransmit = (_) => gate.future;
    return gate;
  }

  List<String> sentNames() => [for (final packet in transmitter.sent) packet.name];

  /// The state saved for the Midea AC.
  AcState savedState() => repository.devices.first.state! as AcState;

  test('a swing tap overlapping a send toggles Midea swing exactly once', () async {
    final gate = holdTransmissions();
    final swingOn = midea.state.copyWith(swingVertical: true);

    final first = queue.send(midea, swingOn);
    // Tapped while the swing frame is still being emitted.
    final second = queue.send(midea, swingOn.copyWith(temperature: 26));
    gate.complete();
    final results = await Future.wait([first, second]);

    // Encoded against the state the AC received: the second frame carries no toggle.
    expect(sentNames(), ['Midea on + swing toggle', 'Midea on']);
    expect(results.every((r) => r.delivered), isTrue);
    expect(queue.deliveredState(midea), swingOn.copyWith(temperature: 26));
    expect(savedState(), swingOn.copyWith(temperature: 26));
  });

  test('swing on then off during a send ends with swing off', () async {
    final gate = holdTransmissions();
    final first = queue.send(midea, midea.state.copyWith(turbo: true));
    final on = queue.send(midea, midea.state.copyWith(turbo: true, swingVertical: true));
    final off = queue.send(midea, midea.state.copyWith(turbo: true));
    gate.complete();
    await Future.wait([first, on, off]);

    // The two pending taps cancel out: no swing toggle at all.
    expect(sentNames(), ['Midea on + turbo toggle', 'Midea on']);
    expect(savedState().swingVertical, isFalse);
  });

  test('taps during a send merge into one more transmission', () async {
    final gate = holdTransmissions();
    final sends = [
      for (final temperature in [26, 27, 28]) queue.send(midea, midea.state.copyWith(temperature: temperature)),
    ];
    gate.complete();
    final results = await Future.wait(sends);

    expect(transmitter.sent, hasLength(2));
    expect([for (final r in results) r.sequence], [1, 2, 2]);
    expect(results.last.state.temperature, 28);
    expect(savedState().temperature, 28);
  });

  test('after a failed send the AC keeps its state, so the retry still carries the toggle', () async {
    var calls = 0;
    transmitter.onTransmit = (_) async {
      if (calls++ == 0) throw PlatformException(code: 'TRANSMIT_FAILED');
    };
    final swingOn = midea.state.copyWith(swingVertical: true);

    final failed = await queue.send(midea, swingOn);
    expect(failed.delivered, isFalse);
    expect(failed.error, isA<PlatformException>());
    expect(queue.deliveredState(midea).swingVertical, isFalse);
    expect(savedState().swingVertical, isFalse);

    final retried = await queue.send(midea, swingOn);
    expect(retried.delivered, isTrue);
    expect(sentNames(), ['Midea on + swing toggle']);
    expect(log.records.map((r) => r.ok), [true, false]);
  });

  test('transmissions never overlap, across ACs, and keep request order', () async {
    final gate = holdTransmissions();
    final sends = [
      queue.send(midea, midea.state.copyWith(temperature: 20)),
      queue.send(coolix, coolix.state.copyWith(temperature: 21)),
      queue.send(midea, midea.state.copyWith(temperature: 22)),
    ];
    gate.complete();
    await Future.wait(sends);

    expect(transmitter.maxInFlight, 1);
    expect(sentNames(), ['Midea on', 'Coolix (Midea-made units) on', 'Midea on']);
    expect([for (final r in log.records.reversed) r.source], ['Living AC', 'Bedroom AC', 'Living AC']);
  });

  test('a new queue starts from the saved state', () async {
    await queue.send(midea, midea.state.copyWith(swingVertical: true));
    final saved = AcDevice.fromDevice(repository.devices.first);

    final restarted = createQueue();
    expect(restarted.deliveredState(saved).swingVertical, isTrue);
    await restarted.send(saved, saved.state.copyWith(temperature: 22));
    expect(sentNames().last, 'Midea on');
  });

  test('pairing again with another code starts from the saved state with the new code', () async {
    await queue.send(midea, midea.state.copyWith(swingVertical: true));
    final repaired = AcDevice.fromDevice(repository.devices.first).copyWith(codeId: 'coolix');

    expect(queue.deliveredState(repaired), repaired.state);
    await queue.send(repaired, repaired.state.copyWith(temperature: 24));
    expect(sentNames().last, 'Coolix (Midea-made units) on');
  });
}
