import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/ac_protocol_encoder.dart';
import 'package:universal_remote/domain/encoders/ac/samsung_ac_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  const encoder = SamsungAcEncoder();
  const cool24 = AcState(mode: AcMode.cool, temperature: 24);

  group('SamsungAcEncoder', () {
    test('power on matches IRremoteESP8266 DecodePowerOnSample', () {
      expect(
        hexBytes(encoder.buildFrame(cool24)),
        '02 92 0f 00 00 00 f0 01 d2 0f 00 00 00 00 01 e2 fe 71 80 11 f0',
      );
    });

    test('power off matches the extended off message', () {
      expect(
        hexBytes(encoder.buildFrame(cool24.copyWith(isPowerOn: false))),
        '02 b2 0f 00 00 00 c0 01 d2 0f 00 00 00 00 01 02 ff 71 80 11 c0',
      );
    });

    test('settings section matches GeneralConstruction and DecodeHeatSample', () {
      expect(hexBytes(encoder.buildFrame(cool24.copyWith(temperature: 20)).sublist(14)), '01 e2 fe 71 40 11 f0');
      final heat = encoder.buildFrame(const AcState(mode: AcMode.heat, temperature: 17, swingVertical: true));
      expect(hexBytes(heat.sublist(14)), '01 02 af 71 10 41 f0');
    });

    test('section checksum matches the SectionChecksums test', () {
      expect(SamsungAcEncoder.sectionChecksum(const [0x02, 0x82, 0x0F, 0x00, 0x00, 0x20, 0xF0], 0), 0xF8);
    });

    test('pulse train: header, then three 7-byte sections', () {
      final p = encoder.encode(cool24).pattern;
      expect(p.sublist(0, 8), [690, 17844, 3086, 8864, 586, 436, 586, 1432]);
      expect(p.length, 2 + 3 * (2 + 112 + 2) - 1);
    });
  });
}
