import 'persian.dart';

/// Local convenience gate explicitly requested for the offline edition.
/// This is not an OTP, license or a server authentication mechanism.
abstract final class LocalAccess {
  static const accessGrantedSetting = 'accessCodeVerified';

  static bool accepts(String code) => asciiDigits(code.trim()) == '22222';

  static bool hasPreviouslyGranted({
    required String? rememberedSetting,
    required String? storeName,
  }) =>
      rememberedSetting == 'true' ||
      (rememberedSetting == null && (storeName?.trim().isNotEmpty ?? false));
}
