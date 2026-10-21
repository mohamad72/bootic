import 'persian.dart';

/// Local convenience gate explicitly requested for the offline edition.
/// This is not an OTP, license or a server authentication mechanism.
abstract final class LocalAccess {
  static bool accepts(String code) => asciiDigits(code.trim()) == '22222';
}
