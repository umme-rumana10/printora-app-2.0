import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/print_option.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';
import '../payment/payment_pending_screen.dart';

class PrintSettingsScreen extends StatefulWidget {
  final List<File> files;

  const PrintSettingsScreen({
    super.key,
    required this.files,
  });

  @override
  State<PrintSettingsScreen> createState() => _PrintSettingsScreenState();
}

class _PrintSettingsScreenState extends State<PrintSettingsScreen> {
  late List<PrintOption> options;
  bool isSubmitting = false;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    options = List.generate(
      widget.files.length,
      (index) => PrintOption(),
    );
  }

  double calculateEstimatedCost() {
    double total = 0;
    for (var opt in options) {
      // Estimated 1 page default, updated precisely after backend page count
      final rate = opt.color ? 10.0 : 2.0;
      total += opt.copies * rate;
    }
    return total;
  }

  Future<void> submitAndProceedToPayment() async {
    if (widget.files.isEmpty) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final machineId = AppState.resolvedMachineId; // QR-scanned or default 'printer001'
      final primaryFile = widget.files.first;
      final primaryOption = options.first;
      final fileName = primaryFile.path.split(Platform.isWindows ? '\\' : '/').last;

      // 1. Create Job in backend (State: CREATED)
      final job = await _api.createJob(
        machineId: machineId,
        copies: primaryOption.copies,
        color: primaryOption.color,
        duplex: primaryOption.duplex,
      );

      // Store job ID globally for easy access
      AppState.currentJobId = job.id;

      // 2. Upload Document (State: UPLOADED, with verified page count & SHA-256)
      await _api.uploadJobFile(
        jobId: job.id,
        filePath: primaryFile.path,
        fileName: fileName,
      );

      // 3. Create Payment Session (State: PAYMENT_PENDING)
      final session = await _api.createPaymentSession(job.id);
      final orderId = session['orderId'] as String;
      final amount = (session['amount'] is num) ? (session['amount'] as num).toDouble() : job.amount;

      if (!mounted) return;

      setState(() {
        isSubmitting = false;
      });

      // 4. Navigate to Razorpay Checkout / Payment Pending
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPendingScreen(
            jobId: job.id,
            orderId: orderId,
            amount: amount,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error initiating print job: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Print Configuration"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.files.length,
              itemBuilder: (context, index) {
                final file = widget.files[index];
                final option = options[index];
                final name = file.path.split(Platform.isWindows ? '\\' : '/').last;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Copies counter
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Number of Copies",
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.blue),
                                  onPressed: () {
                                    if (option.copies > 1) {
                                      setState(() {
                                        option.copies--;
                                      });
                                    }
                                  },
                                ),
                                Text(
                                  "${option.copies}",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                  onPressed: () {
                                    setState(() {
                                      option.copies++;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Color / B&W toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            option.color ? "Color (₹10/page)" : "Black & White (₹2/page)",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            option.color ? "Premium vibrant color print" : "Standard monochrome print",
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: option.color,
                          activeThumbColor: Colors.orange,
                          onChanged: (val) {
                            setState(() {
                              option.color = val;
                            });
                          },
                        ),
                        const Divider(height: 24),

                        // Duplex toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            "Duplex (Double-Sided)",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            "Print on both sides of the sheet",
                            style: TextStyle(fontSize: 12),
                          ),
                          value: option.duplex,
                          activeThumbColor: const Color(0xff2563EB),
                          onChanged: (val) {
                            setState(() {
                              option.duplex = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Price & Proceed Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Estimated Cost:",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      Text(
                        "₹${calculateEstimatedCost().toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff2563EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isSubmitting ? null : submitAndProceedToPayment,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Proceed to Payment",
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
