import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central app configuration loaded from .env at startup.
/// Values fallback to safe defaults for emulator testing.
class AppConfig {
  // Backend API base URL — set in .env
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:5000';

  // Razorpay Test Key ID (safe to include in app — it's not a secret)
  static String get razorpayKeyId =>
      dotenv.env['RAZORPAY_KEY_ID'] ?? 'rzp_test_demo_key';

  // Print pricing (matches backend config)
  static const double bwPricePerPage = 2.0;    // ₹2 per page
  static const double colorPricePerPage = 10.0; // ₹10 per page

  // Default machine for single-machine MVP
  static const String defaultMachineId = 'printer001';
}
