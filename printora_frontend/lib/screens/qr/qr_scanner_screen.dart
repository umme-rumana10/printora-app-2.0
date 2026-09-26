import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../state/app_state.dart';
import '../upload/upload_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool scanned = false;
  final MobileScannerController controller = MobileScannerController();

  void selectKiosk(String kioskId) {
    if (scanned) return;
    scanned = true;
    controller.stop();

    AppState.kioskId = kioskId;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Connected to Kiosk: $kioskId"),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const UploadScreen(),
      ),
    );
  }

  void handleQR(String code) {
    final cleaned = code.trim();
    if (scanned) return;

    if (!cleaned.contains("PRINTORA:KIOSK_ID:")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Scanned: $cleaned")),
      );
      return;
    }

    final kioskId = cleaned.substring(
      cleaned.indexOf("PRINTORA:KIOSK_ID:") + "PRINTORA:KIOSK_ID:".length,
    );

    selectKiosk(kioskId);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Kiosk QR Code"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (scanned) return;
              final barcode = capture.barcodes.first;
              final String? code = barcode.rawValue;
              if (code != null) {
                handleQR(code);
              }
            },
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.black.withValues(alpha: 0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Scan QR on the Vending Machine Screen",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.flash_on),
                        label: const Text("Quick Demo: Connect to printer001"),
                        onPressed: () => selectKiosk("printer001"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
