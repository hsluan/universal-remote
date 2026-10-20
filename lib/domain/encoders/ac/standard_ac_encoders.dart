import 'ac_encoder_registry.dart';
import 'coolix_ac_encoder.dart';
import 'daikin_ac_encoder.dart';
import 'electra_ac_encoder.dart';
import 'gree_ac_encoder.dart';
import 'lg_ac_encoder.dart';
import 'midea_ac_encoder.dart';
import 'mitsubishi_ac_encoder.dart';
import 'panasonic_ac_encoder.dart';
import 'samsung_ac_encoder.dart';
import 'toshiba_ac_encoder.dart';

/// Every AC code the app ships, in auto-search order: one code per protocol,
/// most common in Vietnam first, then the alternate remote families.
AcEncoderRegistry createStandardAcRegistry() {
  return AcEncoderRegistry(const [
    DaikinAcEncoder(),
    PanasonicAcEncoder(model: PanasonicAcModel.dke),
    LgAcEncoder(model: LgAcModel.lg2),
    ElectraAcEncoder(),
    SamsungAcEncoder(),
    ToshibaAcEncoder(),
    MitsubishiAcEncoder(),
    GreeAcEncoder(model: GreeAcModel.yaw1f),
    CoolixAcEncoder(),
    MideaAcEncoder(),
    LgAcEncoder(model: LgAcModel.lg),
    PanasonicAcEncoder(model: PanasonicAcModel.jke),
    GreeAcEncoder(model: GreeAcModel.ybofb),
  ]);
}
