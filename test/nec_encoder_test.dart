import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/nec_encoder.dart';

void main() {
  group('NecEncoder Tests', () {
    test('Standard NEC generates exactly 67 pulse transitions', () {
      final encoder = NecEncoder.standard(address: 0x04, command: 0x08);
      final packet = encoder.encode();

      expect(packet.frequency, equals(38000));
      expect(packet.pattern.length, equals(67));
      expect(packet.pattern[0], equals(9000)); // Header mark
      expect(packet.pattern[1], equals(4500)); // Header space
      expect(packet.pattern.last, equals(560)); // Stop bit mark
    });

    test('Extended NEC sends the 16-bit address low byte first', () {
      final encoder = NecEncoder.extended(address16: 0x1234, command: 0x02);
      expect(encoder.bytes, equals([0x34, 0x12, 0x02, 0xFD]));

      final packet = encoder.encode();
      expect(packet.pattern.length, equals(67));
      expect(packet.frequency, equals(38000));
    });

    test('LG TV Power toggle generates correct inverted bytes', () {
      final encoder = NecEncoder.lgTvPower();
      expect(encoder.bytes, equals([0x04, 0xFB, 0x08, 0xF7]));

      final packet = encoder.encode();
      expect(packet.pattern.length, equals(67));
    });

    test('Zero and One bit pulses follow NEC timing specifications', () {
      // Byte 0x01: LSB is 1, next 7 bits are 0
      final encoder = NecEncoder.rawBytes(bytes: [0x01, 0x00, 0x00, 0x00]);
      final packet = encoder.encode();

      // First bit starts at index 2 (mark) and 3 (space)
      expect(packet.pattern[2], equals(560));
      expect(packet.pattern[3], equals(1690)); // Bit 1 space

      // Second bit starts at index 4 (mark) and 5 (space)
      expect(packet.pattern[4], equals(560));
      expect(packet.pattern[5], equals(560)); // Bit 0 space
    });
  });
}
