import '../models/ir_packet.dart';
import 'ir_protocol_encoder.dart';

/// Converts a learned Pronto hex code ("0000 006D 0022 0002 ...") to a raw packet.
///
/// Layout, in 16-bit hex words:
/// - word 0: `0000` (learned, modulated); other code types are rejected;
/// - word 1: carrier period, in units of 0.241246 µs;
/// - word 2: burst pairs in the once sequence;
/// - word 3: burst pairs in the repeat sequence;
/// - then each burst pair as an on/off count of carrier periods.
///
/// The packet holds the once sequence followed by [repeatCount] copies of the
/// repeat sequence. A code whose once sequence is empty sends its repeat
/// sequence at least once.
class ProntoHexEncoder implements IrProtocolEncoder {
  const ProntoHexEncoder(this.code, {this.repeatCount = 0, this.name = 'Pronto'})
      : assert(repeatCount >= 0, 'repeatCount must not be negative');

  final String code;
  final int repeatCount;
  final String name;

  /// Duration of one Pronto clock tick, in microseconds.
  static const double clockMicros = 0.241246;

  @override
  IrPacket encode() {
    final words = _parseWords(code);
    if (words.length < 4) {
      throw const FormatException('Pronto code needs at least 4 header words');
    }
    if (words[0] != 0x0000) {
      throw FormatException(
        'Unsupported Pronto code type 0x${words[0].toRadixString(16).padLeft(4, '0')}; only 0000 (learned) is supported',
      );
    }
    final periodWord = words[1];
    if (periodWord == 0) {
      throw const FormatException('Pronto carrier period is zero');
    }
    final onceLength = words[2] * 2;
    final repeatLength = words[3] * 2;
    final expected = 4 + onceLength + repeatLength;
    if (words.length != expected) {
      throw FormatException('Pronto code has ${words.length} words, header announces $expected');
    }

    final periodMicros = periodWord * clockMicros;
    final frequency = (1000000 / periodMicros).round();
    final once = words.sublist(4, 4 + onceLength);
    final repeat = words.sublist(4 + onceLength);

    final repeats = once.isEmpty && repeatCount == 0 ? 1 : repeatCount;
    final counts = [
      ...once,
      for (var i = 0; i < repeats; i++) ...repeat,
    ];
    if (counts.isEmpty) {
      throw const FormatException('Pronto code contains no burst pairs');
    }

    final pattern = [for (final count in counts) (count * periodMicros).round()];
    return IrPacket(frequency: frequency, pattern: List.unmodifiable(pattern), name: name);
  }

  static List<int> _parseWords(String code) {
    final tokens = code.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return [
      for (final token in tokens)
        int.tryParse(token, radix: 16) ?? (throw FormatException('Invalid Pronto word "$token"')),
    ];
  }
}
