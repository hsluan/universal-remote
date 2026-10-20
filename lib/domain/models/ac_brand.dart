/// An AC brand in the bundled catalog.
class AcBrand {
  const AcBrand({
    required this.id,
    required this.name,
    required this.codeIds,
    this.rank,
  });

  final String id;
  final String name;

  /// Encoder ids known to work for this brand, most likely first. Empty when
  /// no code is confirmed: the search then tries every code.
  final List<String> codeIds;

  /// Market rank in Vietnam (1 = most common); brands with a rank are suggested first.
  final int? rank;

  bool get isPopular => rank != null;

  bool get hasKnownCodes => codeIds.isNotEmpty;
}
