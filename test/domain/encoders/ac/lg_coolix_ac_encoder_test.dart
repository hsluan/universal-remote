import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/coolix_ac_encoder.dart';
import 'package:universal_remote/domain/encoders/ac/lg_ac_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  group('LgAcEncoder', () {
    const lg = LgAcEncoder(model: LgAcModel.lg);
    const lg2 = LgAcEncoder();

    test('commands match IRremoteESP8266 vectors', () {
      expect(lg.buildCommand(const AcState(mode: AcMode.cool, temperature: 25, fanSpeed: AcFanSpeed.high)), 0x8800A4E);
      expect(lg2.buildCommand(const AcState(mode: AcMode.cool, temperature: 18, fanSpeed: AcFanSpeed.high)), 0x8800347);
      expect(lg.buildCommand(const AcState(isPowerOn: false)), LgAcEncoder.offCommand);
    });

    test('checksum matches the calcChecksum test and the swing constants', () {
      expect(LgAcEncoder.checksum(0x88C0051), 0x1);
      expect(LgAcEncoder.checksum(0x88C0354), 0x4);
      expect(LgAcEncoder.checksum(LgAcEncoder.swingVOn), LgAcEncoder.swingVOn & 0xF);
      expect(LgAcEncoder.checksum(LgAcEncoder.swingVOff), LgAcEncoder.swingVOff & 0xF);
    });

    test('timings: LG 8500/4250, LG2 3200/9900, MSB first', () {
      final p = lg.encode(const AcState(mode: AcMode.cool, temperature: 22, fanSpeed: AcFanSpeed.medium)).pattern;
      // 0x88... starts with bit 1.
      expect(p.sublist(0, 4), [8500, 4250, 550, 1600]);
      expect(p.length, 2 + 56 + 1);
      final p2 = lg2.encode(const AcState()).pattern;
      expect(p2.sublist(0, 4), [3200, 9900, 480, 1600]);
    });

    test('swing change appends the swing command', () {
      const before = AcState();
      final p = lg2.encode(before.copyWith(swingVertical: true), previous: before).pattern;
      expect(p.length, (2 + 56 + 2) + (2 + 56 + 1));
    });
  });

  group('CoolixAcEncoder', () {
    const encoder = CoolixAcEncoder();

    test('commands match IRremoteESP8266 vectors', () {
      expect(encoder.buildCommand(const AcState(mode: AcMode.auto, temperature: 25)), 0xB21FC8);
      expect(encoder.buildCommand(const AcState(mode: AcMode.cool, temperature: 24)), 0xB2BF40);
      expect(encoder.buildCommand(const AcState(mode: AcMode.cool, temperature: 17, fanSpeed: AcFanSpeed.low)), 0xB29F00);
      expect(encoder.buildCommand(const AcState(mode: AcMode.fan)), 0xB2BFE4);
      expect(encoder.buildCommand(const AcState(mode: AcMode.auto, temperature: 20)), 0xB21F28);
      expect(encoder.buildCommand(const AcState(mode: AcMode.heat, temperature: 25)), 0xB2BFCC);
      expect(encoder.buildCommand(const AcState(mode: AcMode.auto, temperature: 26)), 0xB21FD8);
      expect(encoder.buildCommand(const AcState(mode: AcMode.auto, temperature: 28)), 0xB21F88);
      expect(encoder.buildCommand(const AcState(mode: AcMode.fan, fanSpeed: AcFanSpeed.high)), 0xB23FE4);
      expect(encoder.buildCommand(const AcState(isPowerOn: false)), CoolixAcEncoder.offCommand);
    });

    test('pulse train: each byte followed by its inverse, two frames', () {
      final p = encoder.encode(const AcState(mode: AcMode.fan, fanSpeed: AcFanSpeed.high)).pattern;
      // 0xB2 = 1011 0010, MSB first.
      expect(p.sublist(0, 10), [4692, 4416, 552, 1656, 552, 552, 552, 1656, 552, 1656]);
      expect(p.sublist(98, 102), [552, 5244, 4692, 4416]);
      expect(p.length, (2 + 96 + 2) * 2 - 1);
    });

    test('swing and turbo changes append toggle commands', () {
      const before = AcState();
      final p = encoder.encode(before.copyWith(swingVertical: true, turbo: true), previous: before);
      expect(p.pattern.length, 200 * 3 - 1);
      expect(p.totalDurationMicros, lessThan(2000000));
    });
  });
}
