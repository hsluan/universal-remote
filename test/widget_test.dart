import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/app/app_dependencies.dart';
import 'package:universal_remote/domain/encoders/ac/standard_ac_encoders.dart';
import 'package:universal_remote/domain/models/ac_device.dart';
import 'package:universal_remote/domain/models/ac_state.dart';
import 'package:universal_remote/main.dart';
import 'package:universal_remote/ui/features/diagnostics/views/diagnostics_view.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeTransmitter transmitter;
  late InMemoryAcDeviceRepository devices;

  AppDependencies build({List<AcDevice> initial = const []}) {
    transmitter = FakeTransmitter();
    devices = InMemoryAcDeviceRepository(initial);
    return AppDependencies(
      transmitter: transmitter,
      acDevices: devices,
      acBrands: FakeAcBrandRepository(),
      acRegistry: createStandardAcRegistry(),
    );
  }

  Future<void> pumpApp(WidgetTester tester, AppDependencies deps) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UniversalRemoteApp(dependencies: deps));
    await tester.pumpAndSettle();
  }

  testWidgets('empty home leads to the Find my AC wizard with suggestions', (tester) async {
    await pumpApp(tester, build());

    expect(find.text('Control your air conditioner'), findsOneWidget);
    await tester.tap(find.text('Find my AC'));
    await tester.pumpAndSettle();

    expect(find.text('Which brand is your air conditioner?'), findsOneWidget);
    expect(find.text("I don't know the brand"), findsOneWidget);
    expect(find.text('SUGGESTED FOR YOU'), findsOneWidget);
    // Popular brands by rank (Daikin 1, Gree 2, Casper 3); Sharp has no rank.
    final tiles = tester.widgetList<Text>(find.descendant(of: find.byType(GridView), matching: find.byType(Text)));
    expect(tiles.map((t) => t.data).where((d) => d!.length > 1), ['Daikin', 'Gree', 'Casper']);
  });

  testWidgets('pairing: brand, test codes, verify, name, then the remote opens', (tester) async {
    await pumpApp(tester, build());
    await tester.tap(find.text('Find my AC'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gree').first);
    await tester.pumpAndSettle();
    expect(find.text("Let's find your Gree code"), findsOneWidget);

    await tester.tap(find.text('Start testing'));
    await tester.pumpAndSettle();
    expect(find.text('Code 1 of 13'), findsOneWidget);
    expect(find.text('Gree (YAW1F)'), findsOneWidget);
    expect(transmitter.sent, hasLength(1));

    // Not the first one: try the next code.
    await tester.tap(find.text('No, try the next code'));
    await tester.pumpAndSettle();
    expect(find.text('Gree (YBOFB)'), findsOneWidget);
    expect(transmitter.sent, hasLength(2));

    await tester.tap(find.text('Yes, it responded'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Power off'));
    await tester.pumpAndSettle();
    expect(transmitter.sent, hasLength(3));
    await tester.tap(find.text('Yes, it turned off'));
    await tester.pumpAndSettle();

    expect(find.text('Found it: Gree'), findsOneWidget);
    await tester.tap(find.text('Bedroom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and open remote'));
    await tester.pumpAndSettle();

    expect(devices.devices.single.codeId, 'gree_ybofb');
    expect(devices.devices.single.name, 'Gree AC');
    expect(devices.devices.single.room, 'Bedroom');
    // The remote screen is open, with the AC off after the verify step.
    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('Turn on'), findsOneWidget);
  });

  testWidgets('auto search advances by itself until the user answers', (tester) async {
    await pumpApp(tester, build());
    await tester.tap(find.text('Find my AC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I don't know the brand"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start testing'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auto search'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Code 2 of 13'), findsOneWidget);
    expect(transmitter.sent, hasLength(2));

    await tester.tap(find.text('Yes, it responded'));
    await tester.pumpAndSettle();
    expect(find.textContaining('answered!'), findsOneWidget);
  });

  testWidgets('remote: power, temperature debounce and mode', (tester) async {
    const device = AcDevice(id: 'x', name: 'Living AC', brandName: 'Daikin', codeId: 'daikin', room: 'Living room');
    await pumpApp(tester, build(initial: [device]));

    expect(find.text('Living AC'), findsOneWidget);
    expect(find.text('Living room · Off'), findsOneWidget);
    await tester.tap(find.text('Living AC'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(transmitter.sent, hasLength(1));
    expect(find.text('25°'), findsOneWidget);

    await tester.tap(find.byTooltip('Warmer'));
    await tester.pump();
    await tester.tap(find.byTooltip('Warmer'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('27°'), findsOneWidget);
    expect(transmitter.sent, hasLength(2), reason: 'two quick taps send one frame');

    await tester.tap(find.text('Heat'));
    await tester.pumpAndSettle();
    expect(transmitter.sent, hasLength(3));
    expect(devices.devices.single.state, const AcState(mode: AcMode.heat, temperature: 27));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Living room · Heat · 27°C · Fan auto'), findsOneWidget);
  });

  testWidgets('home shows a banner and an error when the phone has no IR blaster', (tester) async {
    const device = AcDevice(id: 'x', name: 'AC', brandName: 'Midea', codeId: 'midea');
    final deps = build(initial: [device]);
    transmitter
      ..hasEmitter = false
      ..failWithCode = 'NO_IR_EMITTER';
    await pumpApp(tester, deps);

    expect(find.textContaining('No IR blaster found'), findsOneWidget);
    await tester.tap(find.byTooltip('Turn on'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no IR blaster'), findsOneWidget);
    expect(devices.devices.single.state.isPowerOn, isFalse);
  });

  testWidgets('diagnostics sends the Samsung32 TV power preset', (tester) async {
    final deps = build();
    await tester.pumpWidget(MaterialApp(home: DiagnosticsView(viewModel: deps.createDiagnosticsViewModel())));
    await tester.pumpAndSettle();

    expect(find.text('Consumer IR Emitter Active'), findsOneWidget);
    expect(find.text('30.0 kHz - 60.0 kHz'), findsOneWidget);
    final button = find.widgetWithText(ElevatedButton, 'Samsung TV Power');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final packet = transmitter.sent.single;
    expect(packet.frequency, 38000);
    expect(packet.pattern.sublist(0, 2), [4480, 4480]);
    expect(packet.pattern.length, 67);
  });
}
