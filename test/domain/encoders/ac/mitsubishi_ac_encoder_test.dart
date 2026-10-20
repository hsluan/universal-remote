import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/ac_protocol_encoder.dart';
import 'package:universal_remote/domain/encoders/ac/mitsubishi_ac_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  const encoder = MitsubishiAcEncoder();

  group('MitsubishiAcEncoder', () {
    test('checksum matches IRremoteESP8266 vectors', () {
      const vectors = [
        [0x23, 0xCB, 0x26, 0x01, 0x00, 0x20, 0x08, 0x06, 0x30, 0x45, 0x67, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1F],
        [0x23, 0xCB, 0x26, 0x01, 0x00, 0x00, 0x18, 0x08, 0x36, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xAB],
        [0x23, 0xCB, 0x26, 0x01, 0x00, 0x20, 0x08, 0x04, 0x00, 0xC0, 0x78, 0x00, 0x00, 0x00, 0x82, 0x00, 0x00, 0xFB],
      ];
      for (final v in vectors) {
        expect(sumBytes(v.take(17)), v[17]);
      }
    });

    test('power, mode, temperature and wide vane match Issue891 (off, cool, 24C)', () {
      final frame = encoder.buildFrame(const AcState(isPowerOn: false, mode: AcMode.cool, temperature: 24));
      expect(frame.sublist(5, 9), [0x00, 0x18, 0x08, 0x36]);
      expect(frame[9], 0xC0); // auto fan flag, vane set flag
    });

    test('on, cool, 27C matches MessageConstuction fields', () {
      final frame = encoder.buildFrame(const AcState(mode: AcMode.cool, temperature: 27, fanSpeed: AcFanSpeed.low));
      expect(frame.sublist(5, 9), [0x20, 0x18, 0x0B, 0x36]);
      expect(frame[9] & 0x07, 1);
      expect(frame[17], sumBytes(frame.take(17)));
    });

    test('swing sets vane 7 and wide vane auto', () {
      final frame = encoder.buildFrame(const AcState(swingVertical: true, swingHorizontal: true));
      expect((frame[9] >> 3) & 0x7, 7);
      expect(frame[8] >> 4, 8);
    });

    test('pulse train: LSB first, sent twice with a 440 µs repeat mark', () {
      final p = encoder.encode(const AcState()).pattern;
      expect(p.sublist(0, 18), [3400, 1750, 450, 1300, 450, 1300, 450, 420, 450, 420, 450, 420, 450, 1300, 450, 420, 450, 420]);
      expect(p.sublist(290, 294), [440, 15500, 3400, 1750]);
      expect(p.length, (2 + 288 + 2) * 2 - 1);
    });
  });
}
