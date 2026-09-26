import 'api_service.dart';

class PaymentService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> initiateJobPayment(String jobId) async {
    return await _api.createPaymentSession(jobId);
  }

  Future<bool> completeSandboxPayment({
    required String orderId,
    required String jobId,
  }) async {
    // Mobile never authorizes printing!
    // Mobile triggers or waits for backend to receive verified webhook
    return await _api.simulatePaymentWebhook(orderId: orderId, jobId: jobId);
  }
}
