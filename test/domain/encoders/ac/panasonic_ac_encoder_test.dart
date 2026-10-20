import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/ac_protocol_encoder.dart';
import 'package:universal_remote/domain/encoders/ac/panasonic_ac_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  group('PanasonicAcEncoder', () {
    test('checksum (0xF4 + sum) matches IRremoteESP8266 captures', () {
      const vectors = [
        // Synthetic / ChecksumCalculation (JKE, cool 25C, off).
        [0x02, 0x20, 0xE0, 0x04, 0x00, 0x00, 0x00, 0x06, 0x02, 0x20, 0xE0, 0x04, 0x00, 0x30, 0x32, 0x80, 0xAF, 0x00, 0x00, 0x06, 0x60, 0x00, 0x00, 0x80, 0x00, 0x06, 0x83],
        // Issue540 (cool 26C, on).
        [0x02, 0x20, 0xE0, 0x04, 0x00, 0x00, 0x00, 0x06, 0x02, 0x20, 0xE0, 0x04, 0x00, 0x39, 0x34, 0x80, 0xAF, 0x0D, 0x00, 0x0E, 0xE0, 0x00, 0x00, 0x81, 0x00, 0x00, 0x1E],
        // DkeIonRealMessages, ion off (DKE, heat 25C, on).
        [0x02, 0x20, 0xE0, 0x04, 0x00, 0x00, 0x00, 0x06, 0x02, 0x20, 0xE0, 0x04, 0x00, 0x4F, 0x32, 0x80, 0xAF, 0x0D, 0x00, 0x06, 0x60, 0x00, 0x00, 0x01, 0x00, 0x06, 0x30],
      ];
      for (final v in vectors) {
        expect(sumBytes(v.take(26), PanasonicAcEncoder.checksumInit), v[26]);
      }
    });

    test('DKE frame carries the same fields as the real DKE remote', () {
      const encoder = PanasonicAcEncoder(model: PanasonicAcModel.dke);
      final frame = encoder.buildFrame(const AcState(
        mode: AcMode.heat,
        temperature: 25,
        swingVertical: true,
        swingHorizontal: true,
      ));
      // Real capture: ... 4F 32 80 AF 0D ... 00 00 01 00 06 (byte 13 low bits are timer flags).
      expect(frame[13] & 0xF1, 0x41);
      expect(frame.sublist(14, 18), [0x32, 0x80, 0xAF, 0x0D]);
      expect(frame.sublist(21, 26), [0x00, 0x00, 0x01, 0x00, 0x06]);
      expect(frame[26], sumBytes(frame.take(26), 0xF4));
    });

    test('JKE frame: cool 25C off, no horizontal swing', () {
      const encoder = PanasonicAcEncoder(model: PanasonicAcModel.jke);
      final frame = encoder.buildFrame(const AcState(
        isPowerOn: false,
        mode: AcMode.cool,
        temperature: 25,
        swingVertical: true,
        swingHorizontal: true,
      ));
      expect(frame.sublist(13, 18), [0x30, 0x32, 0x80, 0xAF, 0x00]);
      expect(frame[23], 0x81);
      expect(encoder.capabilities.swingHorizontal, isFalse);
    });

    test('fan, fixed vane, fan-mode temperature and powerful', () {
      const encoder = PanasonicAcEncoder();
      final frame = encoder.buildFrame(const AcState(mode: AcMode.fan, fanSpeed: AcFanSpeed.high, turbo: true));
      expect(frame[13], 0x61);
      expect(frame[14], 27 << 1);
      expect(frame[16], 0x73); // max fan (4 + 3), vane middle
      expect(frame[21] & 0x20, 0x20);
    });

    test('pulse train: two sections with a 10 ms gap at 36.7 kHz', () {
      final packet = const PanasonicAcEncoder().encode(const AcState());
      final p = packet.pattern;
      expect(packet.frequency, 36700);
      expect(p.sublist(0, 6), [3456, 1728, 432, 432, 432, 1296]); // 0x02 LSB first
      expect(p.sublist(130, 134), [432, 10000, 3456, 1728]);
      expect(p.length, 2 + 128 + 2 + 2 + 19 * 16 + 1);
    });
  });
}
