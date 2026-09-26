import 'package:flutter/material.dart';
import 'package:printora_frontend/screens/qr/qr_scanner_screen.dart';
import 'package:printora_frontend/screens/kiosk/kiosk_selection_screen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FB),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),

          child: Column(
            children: [

              const SizedBox(height: 20),

              Container(
                width: 110,
                height: 110,

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff3B82F6),
                      Color(0xff2563EB),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),

                child: const Icon(
                  Icons.print,
                  color: Colors.white,
                  size: 60,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "PRINTORA",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Print Smart. Print Fast.",
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 60),

              GestureDetector(
                onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
  },

                child: Container(

                  width: double.infinity,
                  padding: const EdgeInsets.all(22),

                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xff3B82F6),
                        Color(0xff2563EB),
                      ],
                    ),

                    borderRadius:
                        BorderRadius.circular(20),

                    boxShadow: [

                      BoxShadow(
                        color: Colors.blue.withValues(alpha: .25),
                        blurRadius: 15,
                        offset: const Offset(0,8),
                      )

                    ],
                  ),

                  child: const Row(

                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [

                      Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 30,
                      ),

                      SizedBox(width: 12),

                      Text(
                        "Scan QR Code",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    ],
                  ),
                ),
              ),

              const SizedBox(height: 35),

              const Text(
                "OR",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 35),

              GestureDetector(

                 onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const KioskSelectionScreen(),
      ),
    );
  },

                child: Container(

                  width: double.infinity,

                  padding: const EdgeInsets.all(22),

                  decoration: BoxDecoration(

                    color: Colors.white,

                    borderRadius:
                        BorderRadius.circular(20),

                    boxShadow: [

                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                      )

                    ],
                  ),

                  child: const Row(

                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [

                      Icon(
                        Icons.store,
                        color: Colors.blue,
                        size: 30,
                      ),

                      SizedBox(width: 12),

                      Text(
                        "Select Kiosk",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    ],
                  ),
                ),
              ),

              const Spacer(),

              const Divider(),

              const SizedBox(height: 10),

              const Text(
                "⚡ Fast • Secure • Paperless",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}