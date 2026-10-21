import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/standard_ac_encoders.dart';
import 'package:universal_remote/domain/models/ac_device.dart';
import 'package:universal_remote/domain/models/ac_state.dart';
import 'package:universal_remote/domain/services/ac_send_queue.dart';
import 'package:universal_remote/domain/use_cases/transmit_ac_state_use_case.dart';
import 'package:universal_remote/domain/use_cases/transmit_ir_packet_use_case.dart';
import 'package:universal_remote/ui/features/ac_remote/view_models/ac_remote_view_model.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const midea = AcDevice(id: 'm', name: 'Living AC', brandName: 'Midea', codeId: 'midea', state: AcState());

  late FakeTransmitter transmitter;
  late InMemoryDeviceRepository repository;
  late AcRemoteViewModel vm;

  setUp(() {
    transmitter = FakeTransmitter();
    repository = InMemoryDeviceRepository([midea.toDevice()]);
    final registry = createStandardAcRegistry();
    final queue = AcSendQueue(
      registry: registry,
      transmitAcState: TransmitAcStateUseCase(transmitPacket: TransmitIrPacketUseCase(transmitter: transmitter)),
      repository: repository,
    );
    vm = AcRemoteViewModel(
      device: midea,
      registry: registry,
      repository: repository,
      sendQueue: queue,
      temperatureDebounce: Duration.zero,
    );
  });

  tearDown(() => vm.dispose());

  Completer<void> holdTransmissions() {
    final gate = Completer<void>();
    transmitter.onTransmit = (_) => gate.future;
    return gate;
  }

  List<String> sentNames() => [for (final packet in transmitter.sent) packet.name];

  test('swing then temperature while the swing frame is in flight: swing toggles once', () async {
    final gate = holdTransmissions();
    vm.toggleSwingVertical();
    vm.increaseTemperature();
    await Future<void>.delayed(Duration.zero); // the (zero) temperature debounce fires
    expect(vm.isSending, isTrue);
    gate.complete();
    await pumpEventQueue();

    expect(sentNames(), ['Midea on + swing toggle', 'Midea on']);
    expect(vm.isSending, isFalse);
    expect(vm.sentCount, 2);
    expect(repository.devices.single.state, const AcState(swingVertical: true, temperature: 26));
  });

  test('mode taps during a send merge, and the indicator flashes once per transmission', () async {
    final gate = holdTransmissions();
    vm
      ..setMode(AcMode.heat)
      ..setMode(AcMode.dry)
      ..setMode(AcMode.fan);
    gate.complete();
    await pumpEventQueue();

    expect(transmitter.sent, hasLength(2));
    expect(vm.sentCount, 2);
    expect(vm.state.mode, AcMode.fan);
    expect((repository.devices.single.state! as AcState).mode, AcMode.fan);
  });

  test('renaming during a send keeps both the name and the delivered state', () async {
    final gate = holdTransmissions();
    vm.toggleTurbo();
    await vm.rename('Bedroom AC');
    gate.complete();
    await pumpEventQueue();

    final stored = repository.devices.single;
    expect(stored.name, 'Bedroom AC');
    expect((stored.state! as AcState).turbo, isTrue);
  });

  test('a failed send shows an error and the next successful one clears it', () async {
    transmitter.failWithCode = 'NO_IR_EMITTER';
    vm.toggleSwingVertical();
    await pumpEventQueue();
    expect(vm.error, contains('no IR blaster'));
    expect((repository.devices.single.state! as AcState).swingVertical, isFalse);

    transmitter.failWithCode = null;
    await vm.resend();
    expect(vm.error, isNull);
    // The AC never got the first toggle, so the resend carries it.
    expect(sentNames(), ['Midea on + swing toggle']);
  });
}
