import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/ac_brand.dart';
import '../../domain/repositories/ac_brand_repository.dart';

/// Reads the bundled AC brand catalog (`assets/ir_db/ac_brands.json`).
class AcBrandRepositoryImpl implements AcBrandRepository {
  AcBrandRepositoryImpl({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String assetPath = 'assets/ir_db/ac_brands.json';

  final AssetBundle _bundle;
  List<AcBrand>? _cache;

  @override
  Future<List<AcBrand>> getBrands() async {
    final cached = _cache;
    if (cached != null) return cached;
    final json = jsonDecode(await _bundle.loadString(assetPath)) as Map<String, dynamic>;
    final brands = [
      for (final entry in json['brands'] as List<dynamic>) parseBrand(entry as Map<String, dynamic>),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _cache = List.unmodifiable(brands);
  }

  static AcBrand parseBrand(Map<String, dynamic> json) {
    return AcBrand(
      id: json['id'] as String,
      name: json['name'] as String,
      codeIds: [for (final id in json['codes'] as List<dynamic>? ?? const []) id as String],
      rank: (json['rank'] as num?)?.toInt(),
    );
  }
}
