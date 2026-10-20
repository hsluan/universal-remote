import '../models/ac_brand.dart';

abstract interface class AcBrandRepository {
  /// All catalog brands, alphabetical.
  Future<List<AcBrand>> getBrands();
}
