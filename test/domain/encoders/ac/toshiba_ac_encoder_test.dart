import 'package:flutter_test/flutter_test.dart';
import 'package:universal_remote/domain/encoders/ac/ac_protocol_encoder.dart';
import 'package:universal_remote/domain/encoders/ac/toshiba_ac_encoder.dart';
import 'package:universal_remote/domain/models/ac_state.dart';

void main() {
  const encoder = ToshibaAcEncoder();

  group('ToshibaAcEncoder', () {
    test('normal frames match IRremoteESP8266 vectors', () {
      expect(hexBytes(encoder.buildFrame(const AcState(mode: AcMode.auto, temperature: 17))), 'f2 0d 03 fc 01 00 00 00 01');
      expect(
        hexBytes(encoder.buildFrame(const AcState(mode: AcMode.cool, temperature: 17, fanSpeed: AcFanSpeed.high))),
        'f2 0d 03 fc 01 00 c1 00 c0',
      );
    });

    test('power off is mode 7', () {
      expect(hexBytes(encoder.buildFrame(const AcState(isPowerOn: false, temperature: 20))), 'f2 0d 03 fc 01 30 07 00 36');
    });

    test('turbo uses the 10-byte long message', () {
      expect(
        hexBytes(encoder.buildFrame(const AcState(mode: AcMode.auto, temperature: 22, turbo: true))),
        'f2 0d 04 fb 09 50 00 00 01 58',
      );
    });

    test('swing messages match the library', () {
      expect(hexBytes(ToshibaAcEncoder.swingFrame(on: true)), 'f2 0d 01 fe 21 01 20');
      expect(hexBytes(ToshibaAcEncoder.swingFrame(on: false)), 'f2 0d 01 fe 21 02 23');
    });

    test('pulse train: MSB first, sent twice; swing change appends the swing message', () {
      const state = AcState();
      final p = encoder.encode(state).pattern;
      expect(p.sublist(0, 18), [4400, 4300, 580, 1600, 580, 1600, 580, 1600, 580, 1600, 580, 490, 580, 490, 580, 1600, 580, 490]);
      expect(p.length, (2 + 144 + 2) * 2 - 1);
      final withSwing = encoder.encode(state.copyWith(swingVertical: true), previous: state).pattern;
      expect(withSwing.length, (2 + 144 + 2) * 2 + (2 + 112 + 2) * 2 - 1);
    });
  });
}
