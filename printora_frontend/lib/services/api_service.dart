import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/kiosk_model.dart';
import '../models/print_job_model.dart';

class ApiService {
  final Dio dio;

  ApiService()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.backendUrl, // Reads from .env at runtime
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );

  // 0. Fetch all registered machines / kiosks
  Future<List<KioskModel>> getMachines() async {
    try {
      final res = await dio.get("/machines");
      if (res.statusCode == 200 && res.data['machines'] != null) {
        final List list = res.data['machines'];
        return list.map((m) => KioskModel.fromJson(m)).toList();
      }
    } catch (e) {
      // Return empty list if failed, screen handles fallback
    }
    return [];
  }

  // 1. Check Machine Status & Readiness
  Future<KioskModel?> getMachineStatus(String machineId) async {
    try {
      final res = await dio.get("/machines/$machineId/status");
      if (res.statusCode == 200 && res.data['machine'] != null) {
        return KioskModel.fromJson(res.data['machine']);
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }

  // 2. Create Job in 'CREATED' state
  Future<PrintJobModel> createJob({
    required String machineId,
    required int copies,
    required bool color,
    required bool duplex,
  }) async {
    final res = await dio.post(
      "/jobs",
      data: {
        "machineId": machineId,
        "copies": copies,
        "color": color,
        "duplex": duplex,
      },
    );
    return PrintJobModel.fromJson(res.data['job']);
  }

  // 3. Upload Document to Job (transitions to 'UPLOADED')
  Future<Map<String, dynamic>> uploadJobFile({
    required String jobId,
    required String filePath,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });

    final res = await dio.post(
      "/jobs/$jobId/upload",
      data: formData,
    );
    return res.data;
  }

  // 4. Create Razorpay Payment Session (transitions to 'PAYMENT_PENDING')
  Future<Map<String, dynamic>> createPaymentSession(String jobId) async {
    final res = await dio.post("/jobs/$jobId/payment-session");
    return res.data;
  }

  // 5. Query Real-time Job Status (Mobile Live Tracking)
  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    final res = await dio.get("/jobs/$jobId/status");
    return res.data;
  }

  // 6. Simulate Razorpay Sandbox Webhook for local end-to-end testing
  Future<bool> simulatePaymentWebhook({
    required String orderId,
    required String jobId,
  }) async {
    try {
      final res = await dio.post(
        "/webhooks/payment",
        options: Options(
          headers: {
            "x-razorpay-signature": "mock_signature_sandbox",
            "x-razorpay-event-id": "evt_sandbox_${DateTime.now().millisecondsSinceEpoch}",
          },
        ),
        data: {
          "event": "payment.captured",
          "order_id": orderId,
          "payment_id": "pay_sandbox_${DateTime.now().millisecondsSinceEpoch}",
          "payload": {
            "payment": {
              "entity": {
                "id": "pay_sandbox_${DateTime.now().millisecondsSinceEpoch}",
                "order_id": orderId,
                "amount": 1000,
                "status": "captured",
              }
            }
          }
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Legacy/Kiosk operator convenience methods
  Future<Response> getKioskJobs(String kioskId) async {
    return await dio.get("/admin/jobs");
  }

  Future<Response> startPrinting(String jobId) async {
    return await dio.post(
      "/device/jobs/$jobId/status",
      data: {"status": "PRINTING"},
    );
  }

  Future<Response> completePrinting(String jobId) async {
    return await dio.post(
      "/device/jobs/$jobId/status",
      data: {"status": "COMPLETED"},
    );
  }
}

