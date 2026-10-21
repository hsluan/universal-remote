import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/app/app_dependencies.dart';
import 'package:universal_remote/domain/devices/device.dart';
import 'package:universal_remote/domain/encoders/ac/standard_ac_encoders.dart';
import 'package:universal_remote/domain/models/ac_device.dart';
import 'package:universal_remote/domain/models/ac_state.dart';
import 'package:universal_remote/main.dart';
import 'package:universal_remote/ui/features/diagnostics/views/diagnostics_view.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeTransmitter transmitter;
  late InMemoryDeviceRepository devices;
  late FakeAppLauncher launcher;

  AppDependencies build({List<Device> initial = const [], Set<String> installedApps = const {}}) {
    transmitter = FakeTransmitter();
    devices = InMemoryDeviceRepository(initial);
    launcher = FakeAppLauncher(installed: {...installedApps});
    return AppDependencies(
      transmitter: transmitter,
      devices: devices,
      acBrands: FakeAcBrandRepository(),
      acRegistry: createStandardAcRegistry(),
      appLauncher: launcher,
    );
  }

  /// Home → Add device → Air conditioner → IR remote option: the Find my AC wizard.
  Future<void> openFindMyAc(WidgetTester tester) async {
    await tester.tap(find.text('Add a device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Air conditioner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Air conditioner with an IR remote'));
    await tester.pumpAndSettle();
  }

  AcState acState(Device device) => device.state! as AcState;

  Future<void> pumpApp(WidgetTester tester, AppDependencies deps) async {
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UniversalRemoteApp(dependencies: deps));
    await tester.pumpAndSettle();
  }

  testWidgets('empty home leads to the Find my AC wizard with suggestions', (tester) async {
    await pumpApp(tester, build());

    expect(find.text('Control everything at home'), findsOneWidget);
    await openFindMyAc(tester);

    expect(find.text('Which brand is your air conditioner?'), findsOneWidget);
    expect(find.text("I don't know the brand"), findsOneWidget);
    expect(find.text('SUGGESTED FOR YOU'), findsOneWidget);
    // Popular brands by rank (Daikin 1, Gree 2, Casper 3); Sharp has no rank.
    final tiles = tester.widgetList<Text>(find.descendant(of: find.byType(GridView), matching: find.byType(Text)));
    expect(tiles.map((t) => t.data).where((d) => d!.length > 1), ['Daikin', 'Gree', 'Casper']);
  });

  testWidgets('pairing: brand, test codes, verify, name, then the remote opens', (tester) async {
    await pumpApp(tester, build());
    await openFindMyAc(tester);

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

    final saved = devices.devices.single;
    expect(saved.connection, const IrConnection(codeId: 'gree_ybofb'));
    expect(saved.kind, DeviceKind.airConditioner);
    expect(saved.name, 'Gree AC');
    expect(saved.room, 'Bedroom');
    // The remote screen is open, with the AC off after the verify step.
    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('Turn on'), findsOneWidget);
  });

  testWidgets('auto search advances by itself until the user answers', (tester) async {
    await pumpApp(tester, build());
    await openFindMyAc(tester);
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
    final deps = build(initial: [device.toDevice()]);
    await pumpApp(tester, deps);

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
    expect(acState(devices.devices.single), const AcState(mode: AcMode.heat, temperature: 27));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Living room · Heat · 27°C · Fan auto'), findsOneWidget);

    final record = deps.sendLog.records.first;
    expect(record.source, 'Living AC');
    expect(record.frameHex, startsWith('11 da 27'));
    expect(deps.sendLog.records, hasLength(3));
  });

  testWidgets('home shows a banner and an error when the phone has no IR blaster', (tester) async {
    const device = AcDevice(id: 'x', name: 'AC', brandName: 'Midea', codeId: 'midea');
    final deps = build(initial: [device.toDevice()]);
    transmitter
      ..hasEmitter = false
      ..failWithCode = 'NO_IR_EMITTER';
    await pumpApp(tester, deps);

    expect(find.textContaining('No IR blaster found'), findsOneWidget);
    await tester.tap(find.byTooltip('Turn on'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no IR blaster'), findsOneWidget);
    expect(acState(devices.devices.single).isPowerOn, isFalse);
  });

  testWidgets('a camera shortcut opens the maker\'s app, or offers to install it', (tester) async {
    await pumpApp(tester, build(installedApps: {'com.xiaomi.smarthome'}));
    await tester.tap(find.text('Add a device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Shortcut to the maker's app"));
    await tester.pumpAndSettle();

    // The installed app is preselected and names the device.
    expect(find.text('Installed'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Xiaomi Home camera'), findsOneWidget);
    final setupList = find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Add shortcut'), 200, scrollable: setupList);
    await tester.tap(find.text('Garage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add shortcut'));
    await tester.pumpAndSettle();

    final saved = devices.devices.single;
    expect(saved.kind, DeviceKind.camera);
    expect(saved.connection, const AppLinkConnection(packageName: 'com.xiaomi.smarthome', appName: 'Xiaomi Home'));
    // Adding a shortcut stays in this app; the card opens the maker's app.
    expect(launcher.launched, isEmpty);

    // Back home: a camera section with the shortcut card.
    expect(find.text('CAMERAS'), findsOneWidget);
    expect(find.text('Garage · Opens Xiaomi Home'), findsOneWidget);
    expect(find.byTooltip('Turn on'), findsNothing);
    await tester.tap(find.text('Xiaomi Home camera'));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['com.xiaomi.smarthome']);

    // Uninstalled: the card offers the store page instead.
    launcher.installed.clear();
    await tester.tap(find.text('Xiaomi Home camera'));
    await tester.pumpAndSettle();
    expect(find.text('Xiaomi Home is not installed on this phone.'), findsOneWidget);
    await tester.tap(find.text('Install'));
    expect(launcher.storePages, ['com.xiaomi.smarthome']);
  });

  testWidgets('kinds without an integration yet show how to set them up', (tester) async {
    await pumpApp(tester, build());
    await tester.tap(find.text('Add a device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Motorbike'));
    await tester.pumpAndSettle();
    expect(find.text('Add it'.toUpperCase()), findsNothing);
  });

  testWidgets('long-press renames or removes any device', (tester) async {
    const camera = Device(
      id: 'c',
      name: 'Gate',
      kind: DeviceKind.camera,
      connection: AppLinkConnection(packageName: 'com.ezviz', appName: 'EZVIZ'),
    );
    await pumpApp(tester, build(initial: [camera]));

    await tester.longPress(find.text('Gate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Front gate');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(devices.devices.single.name, 'Front gate');

    await tester.longPress(find.text('Front gate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(devices.devices, isEmpty);
    expect(find.text('Control everything at home'), findsOneWidget);
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

    // The send log lists it.
    expect(find.text('IR send log'), findsOneWidget);
    final entry = find.textContaining(RegExp(r'^\d\d:\d\d:\d\d  Diagnostics$'));
    await tester.ensureVisible(entry);
    expect(entry, findsOneWidget);
    expect(find.textContaining('67 pulses'), findsOneWidget);
  });
}
