import 'package:flutter/material.dart';
import '../screens/order_tracking/order_tracking_screen.dart';

class OrderSubmittedScreen extends StatelessWidget {
  final String orderId;
  final double totalPrice;

  const OrderSubmittedScreen({
    super.key,
    required this.orderId,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Submitted"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Success Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 90,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "Order Submitted Successfully",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Your files have been added to the printing queue.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 30),

              // Details Card
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Order Details",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 30),
                      ListTile(
                        leading: const Icon(
                          Icons.confirmation_number,
                        ),
                        title: const Text("Order ID"),
                        subtitle: Text(orderId),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.currency_rupee,
                        ),
                        title: const Text("Total Amount"),
                        subtitle: Text(
                          "₹${totalPrice.toStringAsFixed(0)}",
                        ),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.local_printshop,
                        ),
                        title: const Text("Status"),
                        subtitle: const Text("QUEUED"),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time),
                    SizedBox(width: 8),
                    Text(
                      "Waiting for kiosk operator",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.track_changes),
                  label: const Text(
                    "Track Order",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                  onPressed: () {
                    // TODO:
                    // Navigate to OrderTrackingScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          jobId: orderId,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text(
                    "Back To Home",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                  onPressed: () {
                    Navigator.popUntil(
                      context,
                      (route) => route.isFirst,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
