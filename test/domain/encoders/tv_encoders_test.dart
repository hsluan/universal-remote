import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/nec_encoder.dart';
import 'package:universal_remote/domain/encoders/panasonic_encoder.dart';
import 'package:universal_remote/domain/encoders/pronto_hex_encoder.dart';
import 'package:universal_remote/domain/encoders/pulse_train.dart';
import 'package:universal_remote/domain/encoders/samsung_encoder.dart';
import 'package:universal_remote/domain/encoders/sony_sirc_encoder.dart';

void main() {
  group('PulseTrain', () {
    test('merges adjacent intervals and drops leading and trailing spaces', () {
      final train = PulseTrain()
        ..space(100)
        ..mark(10)
        ..mark(5)
        ..space(20)
        ..space(30)
        ..mark(7)
        ..space(99);
      expect(train.build(), [15, 50, 7]);
    });

    test('bits honour bit order and per-symbol timing', () {
      const timing = BitTiming(oneMark: 2, oneSpace: 1, zeroMark: 1, zeroSpace: 1);
      final lsb = (PulseTrain()..bits(0x1, 2, timing)).build();
      final msb = (PulseTrain()..bits(0x1, 2, timing, msbFirst: true)).build();
      expect(lsb, [2, 1, 1]);
      expect(msb, [1, 1, 2]);
    });
  });

  group('SamsungEncoder', () {
    test('TV power is device 7.7, function 2 with a 4.5 ms leader', () {
      const encoder = SamsungEncoder(device: 7, subdevice: 7, command: 2);
      expect(encoder.bytes, [0x07, 0x07, 0x02, 0xFD]);
      final packet = encoder.encode();
      expect(packet.frequency, 38000);
      expect(packet.pattern.sublist(0, 2), [4480, 4480]);
      expect(packet.pattern.length, 67);
    });
  });

  group('SonySircEncoder', () {
    test('SIRC-12 power: three frames on a 45 ms period at 40 kHz', () {
      final packet = SonySircEncoder.tvPower().encode();
      final p = packet.pattern;
      expect(packet.frequency, 40000);
      // Command 21 = 0b0010101, LSB first: 1,0,1,0,1,0,0.
      expect(p.sublist(0, 6), [2400, 600, 1200, 600, 600, 600]);
      final frameLength = 2 + 12 * 2;
      expect(p.length, frameLength * 3 - 1);
      final firstFrame = p.sublist(0, frameLength).fold(0, (a, b) => a + b);
      expect(firstFrame, 45000);
    });

    test('SIRC-20 carries the extended byte', () {
      const encoder = SonySircEncoder(device: 26, command: 1, variant: SircVariant.bits20, extended: 42, frames: 1);
      expect(encoder.encode().pattern.length, 2 + 20 * 2 - 1);
    });
  });

  group('PanasonicEncoder', () {
    test('TV power frame: vendor 0x2002, device 128, function 61, xor check', () {
      final encoder = PanasonicEncoder.tvPower();
      expect(encoder.bytes, [0x02, 0x20, 0x80, 0x00, 0x3D, 0xBD]);
      final packet = encoder.encode();
      expect(packet.frequency, 37000);
      expect(packet.pattern.sublist(0, 2), [3456, 1728]);
      expect(packet.pattern.length, 2 + 48 * 2 + 1);
    });
  });

  group('ProntoHexEncoder', () {
    // LG power (NEC 0x04/0x08) written as a learned Pronto code: once = the NEC
    // frame plus its lead-out gap, repeat = the NEC repeat burst.
    const periodWord = 0x006D;
    const periodMicros = periodWord * ProntoHexEncoder.clockMicros;
    String word(int value) => value.toRadixString(16).padLeft(4, '0').toUpperCase();
    final nec = NecEncoder.lgTvPower().encode().pattern;
    final once = [...nec, 40000];
    const repeat = [9000, 2250, 560, 96000];
    final lgPower = [
      0x0000, periodWord, once.length ~/ 2, repeat.length ~/ 2,
      for (final us in [...once, ...repeat]) (us / periodMicros).round(),
    ].map(word).join(' ');

    test('converts carrier and burst pairs', () {
      final packet = ProntoHexEncoder(lgPower).encode();
      expect(packet.frequency, closeTo(38029, 1));
      expect(packet.pattern.length, once.length);
      for (var i = 0; i < nec.length; i++) {
        expect(packet.pattern[i], closeTo(nec[i], 15), reason: 'interval $i');
      }
    });

    test('repeat sequence is appended on request', () {
      final packet = ProntoHexEncoder(lgPower, repeatCount: 2).encode();
      expect(packet.pattern.length, once.length + repeat.length * 2);
    });

    test('rejects malformed codes', () {
      expect(() => const ProntoHexEncoder('0100 006D 0000 0001 0010 0010').encode(), throwsFormatException);
      expect(() => const ProntoHexEncoder('0000 006D 0002 0000 0010').encode(), throwsFormatException);
      expect(() => const ProntoHexEncoder('0000 zz').encode(), throwsFormatException);
    });
  });
}
