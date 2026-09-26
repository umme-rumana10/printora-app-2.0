import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../state/app_state.dart';
import '../../services/api_service.dart';
import '../../models/kiosk_model.dart';
import '../print_settings/print_settings_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<File> selectedFiles = [];
  KioskModel? kioskStatus;
  bool isCheckingStatus = true;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    checkMachine();
  }

  Future<void> checkMachine() async {
    final kioskId = AppState.kioskId ?? "printer001";
    AppState.kioskId = kioskId;

    final status = await _api.getMachineStatus(kioskId);
    if (!mounted) return;
    setState(() {
      kioskStatus = status;
      isCheckingStatus = false;
    });
  }

  Future<void> pickFile() async {
    final List<XFile> files = await openFiles(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'documents',
          extensions: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
      ],
    );

    if (files.isNotEmpty) {
      setState(() {
        selectedFiles = files.map((f) => File(f.path)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final kioskId = AppState.kioskId ?? "printer001";
    final isMachineReady = kioskStatus == null || kioskStatus!.isReady;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Printora Document Upload"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Machine Status Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isMachineReady ? Colors.blue.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isMachineReady ? Icons.check_circle : Icons.warning,
                              color: isMachineReady ? Colors.green : Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Kiosk: $kioskId",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isMachineReady ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isMachineReady ? "READY" : "ERROR / PAPER OUT",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (kioskStatus != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        "Paper: ${kioskStatus!.paperStatus} • Ink: ${kioskStatus!.inkStatus} • Engine: ${kioskStatus!.printerStatus}",
                        style: TextStyle(
                          color: isMachineReady ? Colors.black87 : Colors.red.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            const Icon(
              Icons.cloud_upload_outlined,
              size: 70,
              color: Color(0xff2563EB),
            ),
            const SizedBox(height: 10),
            const Text(
              "Select Documents to Print",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Supports PDF, JPG, and PNG files",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 25),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isMachineReady ? pickFile : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.file_open),
                label: const Text(
                  "Browse Files (PDF, JPG, PNG)",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (selectedFiles.isNotEmpty) ...[
              const Text(
                "Selected File",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: selectedFiles.map((file) {
                      final name = file.path.split(Platform.isWindows ? '\\' : '/').last;
                      return ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(name, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              selectedFiles.remove(file);
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isMachineReady
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrintSettingsScreen(
                                files: selectedFiles,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text(
                    "Configure Print Settings & Pricing",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
