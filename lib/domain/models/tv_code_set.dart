import 'ir_code.dart';
import 'tv_button.dart';

/// One candidate set of codes for a TV brand (one remote family).
class TvCodeSet {
  const TvCodeSet({
    required this.id,
    required this.brand,
    required this.label,
    required this.codes,
  });

  /// Stable identifier, persisted with paired devices (e.g. `samsung_7_7`).
  final String id;
  final String brand;
  final String label;
  final Map<TvButton, IrCode> codes;

  bool supports(TvButton button) => codes.containsKey(button);

  IrCode? codeFor(TvButton button) => codes[button];

  @override
  String toString() => 'TvCodeSet($id, ${codes.length} buttons)';
}

/// A TV brand with its code sets, most likely first (the pairing wizard tries them in order).
class TvBrand {
  const TvBrand({required this.name, required this.codeSets});

  final String name;
  final List<TvCodeSet> codeSets;
}
