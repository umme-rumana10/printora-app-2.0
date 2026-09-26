import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../config/app_config.dart';
import '../../services/payment_service.dart';
import '../order_tracking/order_tracking_screen.dart';

class PaymentPendingScreen extends StatefulWidget {
  final String jobId;
  final String orderId;
  final double amount;

  const PaymentPendingScreen({
    super.key,
    required this.jobId,
    required this.orderId,
    required this.amount,
  });

  @override
  State<PaymentPendingScreen> createState() => _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends State<PaymentPendingScreen> {
  bool isProcessing = false;
  final PaymentService _paymentService = PaymentService();

  // Razorpay SDK instance
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear(); // Always clear listeners to prevent memory leaks
    super.dispose();
  }

  // ─── Razorpay Event Handlers ─────────────────────────────────────────────

  /// Called when the user successfully pays in Razorpay checkout.
  /// In sandbox mode: Razorpay calls this immediately for test payments.
  /// In production: Razorpay also fires a webhook to your backend.
  ///
  /// Architecture note: We do NOT call backend here to authorize printing.
  /// The BACKEND's verified webhook (POST /webhooks/payment) is the only
  /// trusted trigger. This callback just navigates to the tracking screen.
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('✅ Razorpay payment success: ${response.paymentId}');
    debugPrint('   Order ID: ${response.orderId}');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Payment ${response.paymentId} successful! Waiting for machine assignment...'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );

    // Navigate to live tracking — backend webhook will handle job assignment
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(jobId: widget.jobId),
      ),
    );
  }

  /// Called when payment fails or user dismisses the Razorpay checkout.
  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Razorpay payment error: ${response.code} — ${response.message}');
    if (!mounted) return;

    setState(() => isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Payment failed: ${response.message ?? "Unknown error"}'),
        backgroundColor: Colors.red.shade700,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: openRazorpayCheckout,
        ),
      ),
    );
  }

  /// Called when user selects an external wallet (PhonePe, Paytm etc.)
  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('💳 External wallet selected: ${response.walletName}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet: ${response.walletName}')),
    );
  }

  // ─── Open Razorpay Checkout ───────────────────────────────────────────────

  void openRazorpayCheckout() {
    setState(() => isProcessing = true);

    // Amount in paise (multiply rupees × 100)
    final amountInPaise = (widget.amount * 100).toInt();

    final options = <String, dynamic>{
      'key': AppConfig.razorpayKeyId, // Loaded from .env
      'amount': amountInPaise,
      'currency': 'INR',
      'name': 'Printora',
      'description': 'Print Job – Order ${widget.orderId}',
      'order_id': widget.orderId, // Must match the Razorpay order created by backend
      'prefill': {
        'contact': '9999999999', // Prefill for sandbox testing
        'email': 'user@printora.com',
      },
      'theme': {
        'color': '#2563EB', // Printora brand blue
      },
      'retry': {
        'enabled': false, // Let user retry manually via our UI
      },
      'send_sms_hash': true, // Auto-read OTP on Android
      'external': {
        'wallets': ['paytm', 'phonepe'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('❌ Razorpay open() error: $e');
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Sandbox Simulation (Dev Only) ───────────────────────────────────────

  /// Use this button in development ONLY when running without a real Android/iOS device.
  /// Directly calls the backend webhook simulation endpoint.
  Future<void> simulateSandboxPayment() async {
    setState(() => isProcessing = true);
    final success = await _paymentService.completeSandboxPayment(
      orderId: widget.orderId,
      jobId: widget.jobId,
    );

    if (!mounted) return;
    setState(() => isProcessing = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(jobId: widget.jobId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Simulation failed — is the backend running?'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Razorpay Checkout'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Razorpay logo circle
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payment,
                size: 70,
                color: Color(0xff2563EB),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Secure Payment',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete your print job payment via Razorpay',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),

            const SizedBox(height: 30),

            // Order Summary Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.confirmation_number, color: Color(0xff2563EB)),
                      title: const Text('Job ID'),
                      subtitle: Text(
                        widget.jobId,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.receipt_long, color: Colors.deepPurple),
                      title: const Text('Razorpay Order'),
                      subtitle: Text(
                        widget.orderId,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.currency_rupee, color: Colors.green),
                      title: const Text('Amount Payable'),
                      trailing: Text(
                        '₹${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ── Primary CTA: Real Razorpay SDK ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
                icon: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(
                  isProcessing ? 'Opening Razorpay...' : 'Pay ₹${widget.amount.toStringAsFixed(0)} via Razorpay',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                onPressed: isProcessing ? null : openRazorpayCheckout,
              ),
            ),

            const SizedBox(height: 20),

            // ── Secondary: Sandbox Simulate (Dev only) ──
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text(
                'Simulate Payment (Dev/Web Only)',
                style: TextStyle(fontSize: 14),
              ),
              onPressed: isProcessing ? null : simulateSandboxPayment,
            ),

            const SizedBox(height: 16),

            // Security note
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Payments secured by Razorpay. ₹${widget.amount.toStringAsFixed(2)} will be charged.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
