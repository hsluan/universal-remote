import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/ac_protocol_encoder.dart';
import 'package:universal_remote/domain/encoders/ac/electra_ac_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  const encoder = ElectraAcEncoder();

  String frame(AcState state) => hexBytes(encoder.buildFrame(state));

  group('ElectraAcEncoder vs IRremoteESP8266', () {
    test('HumanReadable vectors', () {
      expect(frame(const AcState(mode: AcMode.cool, temperature: 32)), 'c3 c7 e0 00 a0 00 20 00 00 20 00 40 8a');
      expect(frame(const AcState(mode: AcMode.cool, temperature: 16)), 'c3 47 e0 00 a0 00 20 00 00 20 00 41 0b');
      expect(
        frame(const AcState(mode: AcMode.cool, temperature: 16, fanSpeed: AcFanSpeed.low)),
        'c3 47 e0 00 60 00 20 00 00 20 00 41 cb',
      );
    });

    test('checksum (sum of bytes 0-11) matches real captures from other Electra remotes', () {
      const vectors = [
        [0xC3, 0x87, 0xF6, 0x28, 0x60, 0x00, 0x20, 0x00, 0x00, 0x20, 0x00, 0x05, 0x0D],
        [0xC3, 0x87, 0xE0, 0x00, 0x60, 0x40, 0x20, 0x00, 0x00, 0x20, 0x00, 0x08, 0x12],
        [0xC3, 0x9F, 0xE0, 0x40, 0xA0, 0x00, 0x88, 0x66, 0x00, 0x30, 0x00, 0x1E, 0x5E],
      ];
      for (final v in vectors) {
        expect(sumBytes(v.take(12)), v[12]);
      }
    });
  });

  // Frames decoded from the Casper SC-09FS32 remote's Broadlink captures
  // (SmartIR codes/climate/3240.json, MIT), keyed mode/fan/swing/temperature.
  group('ElectraAcEncoder vs real Casper captures', () {
    test('cool/auto/off/24', () {
      expect(frame(const AcState(mode: AcMode.cool, temperature: 24)), 'c3 87 e0 00 a0 00 20 00 00 20 00 40 4a');
    });

    test('cool/auto/vertical, horizontal and both swing at 24', () {
      const base = AcState(mode: AcMode.cool, temperature: 24);
      expect(frame(base.copyWith(swingVertical: true)), 'c3 80 e0 00 a0 00 20 00 00 20 00 40 43');
      expect(frame(base.copyWith(swingHorizontal: true)), 'c3 87 00 00 a0 00 20 00 00 20 00 40 6a');
      expect(
        frame(base.copyWith(swingVertical: true, swingHorizontal: true)),
        'c3 80 00 00 a0 00 20 00 00 20 00 40 63',
      );
    });

    test('fan speeds and turbo at cool 24', () {
      const base = AcState(mode: AcMode.cool, temperature: 24);
      expect(frame(base.copyWith(fanSpeed: AcFanSpeed.low)), 'c3 87 e0 00 60 00 20 00 00 20 00 40 0a');
      expect(frame(base.copyWith(fanSpeed: AcFanSpeed.medium)), 'c3 87 e0 00 40 00 20 00 00 20 00 40 ea');
      expect(frame(base.copyWith(fanSpeed: AcFanSpeed.high)), 'c3 87 e0 00 20 00 20 00 00 20 00 40 ca');
      expect(frame(base.copyWith(turbo: true)), 'c3 87 e0 00 20 40 20 00 00 20 00 40 0a');
    });

    test('heat modes', () {
      expect(frame(const AcState(mode: AcMode.heat, temperature: 24)), 'c3 87 e0 00 a0 00 80 00 00 20 00 40 aa');
      expect(
        frame(const AcState(
          mode: AcMode.heat,
          temperature: 30,
          fanSpeed: AcFanSpeed.high,
          swingVertical: true,
          swingHorizontal: true,
        )),
        'c3 b0 00 00 20 00 80 00 00 20 00 40 73',
      );
    });

    test('power off', () {
      expect(
        frame(const AcState(isPowerOn: false, mode: AcMode.cool, temperature: 32)),
        'c3 c7 e0 00 a0 00 20 00 00 00 00 45 6f',
      );
    });

    test('pulse train uses the Casper remote timings, one frame', () {
      final packet = encoder.encode(const AcState());
      final p = packet.pattern;
      expect(packet.frequency, 38000);
      // 0xC3 LSB first: 1, 1, 0, 0, ...
      expect(p.sublist(0, 8), [9556, 4893, 558, 1839, 558, 1839, 558, 624]);
      expect(p.length, 2 + 104 * 2 + 1);
    });
  });
}
