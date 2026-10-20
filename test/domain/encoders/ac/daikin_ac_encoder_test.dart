import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/ac_protocol_encoder.dart';
import 'package:universal_remote/domain/encoders/ac/daikin_ac_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  const encoder = DaikinAcEncoder();

  group('DaikinAcEncoder', () {
    test('default state constant carries valid section checksums', () {
      const s = DaikinAcEncoder.defaultState;
      expect(sumBytes(s.sublist(0, 7)), s[7]);
      expect(sumBytes(s.sublist(8, 15)), s[15]);
      expect(sumBytes(s.sublist(16, 34)), s[34]);
    });

    test('section checksum matches the real ARC remote capture', () {
      // IRremoteESP8266 TestDecodeDaikin.RealExample (Cool, 29C, powerful).
      const capture = [
        0x11, 0xDA, 0x27, 0x00, 0xC5, 0x00, 0x00, 0xD7, //
        0x11, 0xDA, 0x27, 0x00, 0x42, 0x3A, 0x05, 0x93,
        0x11, 0xDA, 0x27, 0x00, 0x00, 0x3F, 0x3A, 0x00, 0xA0, 0x00, 0x0A, 0x25, 0x17, 0x01, 0x00, 0xC0, 0x00, 0x00, 0x32,
      ];
      expect(sumBytes(capture.sublist(8, 15)), 0x93);
      expect(sumBytes(capture.sublist(16, 34)), 0x32);
    });

    test('matches IRremoteESP8266 MessageConstuction: on, cool, 27C, fan min, swing H', () {
      final frame = encoder.buildFrame(const AcState(
        mode: AcMode.cool,
        temperature: 27,
        fanSpeed: AcFanSpeed.low,
        swingHorizontal: true,
      ));
      expect(hexBytes(frame), hexBytes(const [
        0x11, 0xDA, 0x27, 0x00, 0xC5, 0x00, 0x00, 0xD7, //
        0x11, 0xDA, 0x27, 0x00, 0x42, 0x00, 0x00, 0x54,
        0x11, 0xDA, 0x27, 0x00, 0x00, 0x39, 0x36, 0x00, 0x30, 0x0F, 0x00, 0x06, 0x60, 0x00, 0x00, 0xC0, 0x00, 0x00, 0xE6,
      ]));
    });

    test('encodes power, mode, temperature, fan, swing and powerful fields', () {
      final frame = encoder.buildFrame(const AcState(
        isPowerOn: false,
        mode: AcMode.heat,
        temperature: 22,
        fanSpeed: AcFanSpeed.auto,
        swingVertical: true,
        turbo: true,
      ));
      expect(frame[21], 0x48); // heat, bit 3, power off
      expect(frame[22], 44); // 22C in half degrees
      expect(frame[24], 0xAF); // fan auto, swing V on
      expect(frame[25], 0x00);
      expect(frame[29], 0x01);
      expect(frame[34], sumBytes(frame.sublist(16, 34)));
    });

    test('clamps the temperature to the remote range', () {
      expect(encoder.buildFrame(const AcState(temperature: 5))[22], 18 * 2);
      expect(encoder.buildFrame(const AcState(temperature: 40))[22], 32 * 2);
    });

    test('pulse train: 5-bit leader, then three sections at 38 kHz', () {
      final packet = encoder.encode(const AcState());
      final p = packet.pattern;
      expect(packet.frequency, 38000);
      expect(p.sublist(0, 10), everyElement(428));
      expect(p.sublist(10, 14), [428, 29428, 3650, 1623]);
      // 12 leader entries + 132 + 132 + 308 section entries, trailing gap dropped.
      expect(p.length, 583);
      expect(p.last, 428);
    });
  });
}
