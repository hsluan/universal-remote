import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/ac_protocol_encoder.dart';
import 'package:universal_remote/domain/encoders/ac/midea_ac_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  const encoder = MideaAcEncoder();

  group('MideaAcEncoder', () {
    test('Celsius frames match IRremoteESP8266 CelsiusRemoteTemp', () {
      const low = AcState(mode: AcMode.cool, fanSpeed: AcFanSpeed.low);
      expect(hexBytes(encoder.buildFrame(low.copyWith(temperature: 17))), 'a1 88 40 ff ff 56');
      expect(hexBytes(encoder.buildFrame(low.copyWith(temperature: 30))), 'a1 88 4d ff ff 5d');
    });

    test('checksum matches the library assertions', () {
      expect(MideaAcEncoder.checksum(const [0xA1, 0x82, 0x6F, 0xFF, 0xFF]), 0x62);
      expect(MideaAcEncoder.checksum(const [0x12, 0x34, 0x56, 0x78, 0x90]), 0xDF);
      expect(MideaAcEncoder.checksum(const [0xFF, 0xFF, 0xFF, 0xFF, 0xFF]), 0xA0);
      expect(MideaAcEncoder.checksum(MideaAcEncoder.toggleSwingV), MideaAcEncoder.toggleSwingV[5]);
      expect(MideaAcEncoder.checksum(MideaAcEncoder.toggleTurbo), MideaAcEncoder.toggleTurbo[5]);
    });

    test('power off clears the power bit', () {
      final frame = encoder.buildFrame(const AcState(isPowerOn: false, mode: AcMode.heat, fanSpeed: AcFanSpeed.high));
      expect(frame[1], 0x1B);
    });

    test('pulse train: MSB first, then the inverted copy', () {
      final p = encoder.encode(const AcState()).pattern;
      expect(p.sublist(0, 4), [4480, 4480, 560, 1680]); // 0xA1: first bit 1
      expect(p.sublist(98, 104), [560, 5600, 4480, 4480, 560, 560]); // ~0xA1: first bit 0
      expect(p.length, (2 + 96 + 2) * 2 - 1);
    });

    test('swing and turbo changes append toggle messages', () {
      const before = AcState();
      final plain = encoder.encode(before.copyWith(temperature: 24), previous: before).pattern;
      final swing = encoder.encode(before.copyWith(swingVertical: true), previous: before).pattern;
      final both = encoder.encode(before.copyWith(swingVertical: true, turbo: true), previous: before);
      expect(plain.length, 199);
      expect(swing.length, 199 * 2 + 1);
      expect(both.pattern.length, 199 * 3 + 2);
      expect(both.totalDurationMicros, lessThan(2000000));
    });
  });
}
