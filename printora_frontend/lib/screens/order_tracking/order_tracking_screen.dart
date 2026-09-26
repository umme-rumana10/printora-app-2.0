import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String jobId;

  const OrderTrackingScreen({
    super.key,
    required this.jobId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? jobData;
  Map<String, dynamic>? machineData;
  bool loading = true;
  Timer? pollTimer;

  final List<String> statusSteps = [
    "UPLOADED",
    "PAID",
    "ASSIGNED_TO_MACHINE",
    "DOWNLOADING",
    "READY_TO_PRINT",
    "PRINTING",
    "COMPLETED"
  ];

  @override
  void initState() {
    super.initState();
    fetchStatus();
    pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => fetchStatus());
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchStatus() async {
    try {
      final res = await _api.getJobStatus(widget.jobId);
      if (!mounted) return;
      setState(() {
        jobData = res['job'];
        machineData = res['machine'];
        loading = false;
      });

      // If completed or failed, we can reduce polling frequency
      final currentStatus = jobData?['status'];
      if (currentStatus == 'COMPLETED' || currentStatus == 'FAILED' || currentStatus == 'REFUNDED') {
        pollTimer?.cancel();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  int getStepIndex(String currentStatus) {
    return statusSteps.indexOf(currentStatus);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Track Print Job")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentStatus = jobData?['status'] ?? 'UNKNOWN';
    final isCompleted = currentStatus == 'COMPLETED';
    final isFailed = currentStatus == 'FAILED';
    final isRefunded = currentStatus == 'REFUNDED';
    final currentIndex = getStepIndex(currentStatus);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Job Tracking"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchStatus,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchStatus,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status Header Card
            Card(
              elevation: 4,
              color: isCompleted
                  ? Colors.green.shade50
                  : (isFailed ? Colors.red.shade50 : Colors.blue.shade50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : (isFailed
                              ? Icons.error
                              : (isRefunded ? Icons.money_off : Icons.print_outlined)),
                      size: 55,
                      color: isCompleted
                          ? Colors.green
                          : (isFailed ? Colors.red : const Color(0xff2563EB)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentStatus,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? Colors.green.shade800
                            : (isFailed ? Colors.red.shade800 : const Color(0xff1E40AF)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Machine: ${jobData?['machine_id'] ?? 'printer001'}",
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            const Text(
              "Progress Timeline",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            // Timeline Steps
            ...List.generate(statusSteps.length, (idx) {
              final step = statusSteps[idx];
              final isDone = currentIndex >= idx;
              final isCurrent = currentIndex == idx;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? Colors.green
                              : (isCurrent ? Colors.blue : Colors.grey.shade300),
                        ),
                        child: Icon(
                          isDone ? Icons.check : Icons.circle,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (idx < statusSteps.length - 1)
                        Container(
                          width: 3,
                          height: 35,
                          color: isDone ? Colors.green : Colors.grey.shade300,
                        ),
                    ],
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        step.replaceAll("_", " "),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isDone || isCurrent ? Colors.black87 : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 30),

            // Job Details Summary
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Job Details",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    Text("Job ID: ${widget.jobId}"),
                    const SizedBox(height: 6),
                    Text("Pages: ${jobData?['pages'] ?? 1}"),
                    const SizedBox(height: 6),
                    Text("Copies: ${jobData?['copies'] ?? 1}"),
                    const SizedBox(height: 6),
                    Text("Color: ${jobData?['color'] == true ? 'Yes' : 'No'}"),
                    const SizedBox(height: 6),
                    Text("Duplex: ${jobData?['duplex'] == true ? 'Yes' : 'No'}"),
                    const SizedBox(height: 6),
                    Text("Total Paid: ₹${jobData?['amount'] ?? 0}"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            if (isCompleted)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text("Done & Back to Home"),
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
