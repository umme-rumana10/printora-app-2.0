import '../config/app_config.dart';

class AppState {
  /// Set when user scans a kiosk QR code: format PRINTORA:KIOSK_ID:<id>
  static String? kioskId;

  /// Set after a job is created — lets tracking screen be opened from anywhere
  static String? currentJobId;

  /// Returns the scanned kiosk ID or falls back to the single default machine
  static String get resolvedMachineId =>
      kioskId ?? AppConfig.defaultMachineId;

  static void reset() {
    kioskId = null;
    currentJobId = null;
  }
}