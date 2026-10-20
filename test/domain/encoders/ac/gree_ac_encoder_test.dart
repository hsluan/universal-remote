import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/ac_protocol_encoder.dart';
import 'package:universal_remote/domain/encoders/ac/gree_ac_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  const coolLowSwing = AcState(mode: AcMode.cool, temperature: 23, fanSpeed: AcFanSpeed.low, swingVertical: true);

  group('GreeAcEncoder', () {
    test('YBOFB on matches IRremoteESP8266 Issue814Power', () {
      const encoder = GreeAcEncoder(model: GreeAcModel.ybofb);
      expect(hexBytes(encoder.buildFrame(coolLowSwing)), '59 07 20 50 01 20 00 c0');
    });

    test('YAW1F on sets the model bit', () {
      const encoder = GreeAcEncoder();
      expect(hexBytes(encoder.buildFrame(coolLowSwing)), '59 07 60 50 01 20 00 c0');
    });

    test('off is the same frame for both models', () {
      final off = coolLowSwing.copyWith(isPowerOn: false);
      expect(hexBytes(const GreeAcEncoder().buildFrame(off)), '51 07 20 50 01 20 00 40');
      expect(hexBytes(const GreeAcEncoder(model: GreeAcModel.ybofb).buildFrame(off)), '51 07 20 50 01 20 00 40');
    });

    test('checksum matches other real captures', () {
      expect(GreeAcEncoder.checksum(const [0x19, 0x0A, 0x60, 0x50, 0x02, 0x23, 0x00, 0x00]), 0xF);
      expect(GreeAcEncoder.checksum(const [0x1D, 0x09, 0x60, 0x58, 0x00, 0x20, 0x00, 0x00]), 0xA);
    });

    test('auto mode forces 25C and dry mode forces the lowest fan', () {
      final auto = const GreeAcEncoder().buildFrame(const AcState(mode: AcMode.auto, temperature: 18));
      expect(auto[1] & 0x0F, 25 - 16);
      final dry = const GreeAcEncoder().buildFrame(const AcState(mode: AcMode.dry, fanSpeed: AcFanSpeed.high));
      expect((dry[0] >> 4) & 0x3, 1);
    });

    test('pulse train: block footer 010 and 19.98 ms gap between blocks', () {
      final packet = const GreeAcEncoder().encode(coolLowSwing);
      final p = packet.pattern;
      expect(packet.frequency, 38000);
      expect(p.sublist(0, 2), [9000, 4500]);
      expect(p.sublist(66, 74), [620, 540, 620, 1600, 620, 540, 620, 19980]);
      expect(p.length, 2 + 64 + 6 + 2 + 64 + 1);
    });
  });
}
