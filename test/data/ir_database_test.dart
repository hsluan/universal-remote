import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/data/repositories/ac_brand_repository_impl.dart';
import 'package:universal_remote/domain/encoders/ac/standard_ac_encoders.dart';
import 'package:universal_remote/domain/encoders/nec_encoder.dart';
import 'package:universal_remote/domain/encoders/panasonic_encoder.dart';
import 'package:universal_remote/domain/encoders/samsung_encoder.dart';
import 'package:universal_remote/domain/encoders/sony_sirc_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';
import 'package:universal_remote/domain/models/tv_button.dart';
import 'package:universal_remote/domain/use_cases/transmit_ir_packet_use_case.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ac_brands.json', () {
    test('every brand code exists in the registry', () async {
      final registry = createStandardAcRegistry();
      final brands = await AcBrandRepositoryImpl().getBrands();
      expect(brands, isNotEmpty);
      expect(brands.map((b) => b.id).toSet().length, brands.length);
      for (final brand in brands) {
        for (final id in brand.codeIds) {
          expect(registry.find(id), isNotNull, reason: '${brand.name} references unknown code "$id"');
        }
      }
      expect(brands.where((b) => b.isPopular), isNotEmpty);
    });

    test('Casper tries the Electra code first (verified against Casper captures)', () async {
      final brands = await AcBrandRepositoryImpl().getBrands();
      final casper = brands.singleWhere((b) => b.id == 'casper');
      expect(casper.codeIds.first, 'electra');
      expect(createStandardAcRegistry().candidatesFor(casper.codeIds).first.id, 'electra');
    });

    test('every registered code encodes probe and off frames within the platform limit', () {
      for (final encoder in createStandardAcRegistry().all) {
        for (final state in [AcState.probe, AcState.probe.copyWith(isPowerOn: false)]) {
          final packet = encoder.encode(state);
          expect(packet.pattern.length.isOdd, isTrue, reason: '${encoder.id} must end on a mark');
          expect(packet.pattern.every((v) => v > 0), isTrue);
          expect(packet.totalDurationMicros, lessThan(TransmitIrPacketUseCase.maxPatternDurationMicros));
        }
      }
    });
  });

  group('tv_codesets.json', () {
    test('every code set defines the essential buttons and encodes', () async {
      final json = jsonDecode(await rootBundle.loadString('assets/ir_db/tv_codesets.json')) as Map<String, dynamic>;
      final ids = <String>{};
      for (final brand in json['brands'] as List<dynamic>) {
        for (final set in (brand as Map<String, dynamic>)['codeSets'] as List<dynamic>) {
          final codeSet = set as Map<String, dynamic>;
          expect(ids.add(codeSet['id'] as String), isTrue, reason: 'duplicate id ${codeSet['id']}');
          final buttons = codeSet['buttons'] as Map<String, dynamic>;
          for (final essential in TvButton.essentials) {
            expect(buttons.containsKey(essential.key), isTrue, reason: '${codeSet['id']} lacks ${essential.key}');
          }
          for (final entry in buttons.entries) {
            expect(TvButton.fromKey(entry.key), isNotNull, reason: 'unknown button ${entry.key}');
            final value = entry.value;
            final device = value is Map ? value['device'] as int : codeSet['device'] as int;
            final subdevice = value is Map ? value['subdevice'] as int? : codeSet['subdevice'] as int?;
            final function = value is Map ? value['function'] as int : value as int;
            final packet = switch (codeSet['protocol']) {
              'nec' => NecEncoder.standard(address: device, command: function).encode(),
              'samsung' => SamsungEncoder(device: device, subdevice: subdevice!, command: function).encode(),
              'sony12' => SonySircEncoder(device: device, command: function).encode(),
              'panasonic' => PanasonicEncoder(device: device, subdevice: subdevice!, command: function).encode(),
              final other => fail('unsupported protocol $other'),
            };
            expect(packet.pattern, isNotEmpty);
          }
        }
      }
    });
  });

  test('AcBrandRepositoryImpl parses ranks and sorts by name', () async {
    final bundle = _StringBundle(
      '{"brands":[{"id":"b","name":"Beta","codes":["x"],"rank":2},{"id":"a","name":"alpha"}]}',
    );
    final brands = await AcBrandRepositoryImpl(bundle: bundle).getBrands();
    expect(brands.map((b) => b.name), ['alpha', 'Beta']);
    expect(brands.first.codeIds, isEmpty);
    expect(brands.last.rank, 2);
  });
}

class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.content);

  final String content;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(utf8.encode(content));
}
