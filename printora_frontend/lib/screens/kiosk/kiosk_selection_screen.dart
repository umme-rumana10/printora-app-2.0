import 'package:flutter/material.dart';
import '../../models/kiosk_model.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';
import '../upload/upload_screen.dart';
import '../qr/qr_scanner_screen.dart';

class KioskSelectionScreen extends StatefulWidget {
  const KioskSelectionScreen({super.key});

  @override
  State<KioskSelectionScreen> createState() => _KioskSelectionScreenState();
}

class _KioskSelectionScreenState extends State<KioskSelectionScreen> {
  final ApiService _api = ApiService();
  List<KioskModel> _kiosks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchKiosks();
  }

  Future<void> _fetchKiosks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final kiosks = await _api.getMachines();
      if (!mounted) return;
      setState(() {
        _kiosks = kiosks;
        _isLoading = false;
        if (kiosks.isEmpty) {
          _errorMessage = null; // Clean empty state handled in UI
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load kiosks from server. Check your connection.';
      });
    }
  }

  void _onSelectKiosk(String kioskId) {
    AppState.kioskId = kioskId;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Connected to $kioskId'),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const UploadScreen(),
      ),
    );
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController(text: 'printer001');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Enter Kiosk ID', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the kiosk or machine ID shown on the vending machine screen:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. printer001',
                prefixIcon: const Icon(Icons.print_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final id = textController.text.trim();
              if (id.isNotEmpty) {
                Navigator.pop(ctx);
                _onSelectKiosk(id);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Select Printora Kiosk',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR Code',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const QRScannerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchKiosks,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchKiosks,
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                ),
                onPressed: _showManualEntryDialog,
                icon: const Icon(Icons.keyboard, color: Color(0xFF2563EB)),
                label: const Text(
                  'Manual Entry',
                  style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: () => _onSelectKiosk('printer001'),
                icon: const Icon(Icons.flash_on),
                label: const Text(
                  'Quick Connect',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Discovering nearby kiosks...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.black80),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _fetchKiosks,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => _onSelectKiosk('printer001'),
              child: const Text('Continue with default kiosk (printer001)'),
            ),
          ),
        ],
      );
    }

    if (_kiosks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.storefront_outlined, size: 56, color: Color(0xFF2563EB)),
                const SizedBox(height: 14),
                const Text(
                  'No Kiosks Found on Server',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can connect directly to the primary simulator kiosk or scan a QR code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _onSelectKiosk('printer001'),
                  icon: const Icon(Icons.print),
                  label: const Text('Connect to printer001'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _kiosks.length,
      itemBuilder: (context, index) {
        final kiosk = _kiosks[index];
        return _buildKioskCard(kiosk);
      },
    );
  }

  Widget _buildKioskCard(KioskModel kiosk) {
    final bool isOnline = kiosk.status.toUpperCase() == 'ONLINE';
    final bool isReady = kiosk.isReady;
    final bool isPaperOk = kiosk.paperStatus.toUpperCase() != 'OUT';

    Color statusColor;
    String statusText;

    if (!isOnline) {
      statusColor = Colors.red;
      statusText = 'OFFLINE';
    } else if (kiosk.maintenanceMode) {
      statusColor = Colors.orange;
      statusText = 'MAINTENANCE';
    } else if (!isPaperOk) {
      statusColor = Colors.orange;
      statusText = 'PAPER OUT';
    } else {
      statusColor = const Color(0xFF16A34A);
      statusText = 'READY';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isReady ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
          width: isReady ? 1.5 : 1.0,
        ),
      ),
      elevation: isReady ? 2 : 0,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isReady
            ? () => _onSelectKiosk(kiosk.id)
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kiosk ${kiosk.id} is currently $statusText and cannot accept print jobs.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isReady
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.print,
                      color: isReady ? const Color(0xFF2563EB) : Colors.grey,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              kiosk.id,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                kiosk.location,
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTelemetryBadge(
                    icon: Icons.description_outlined,
                    label: 'Paper: ${kiosk.paperStatus}',
                    isOk: isPaperOk,
                  ),
                  const SizedBox(width: 12),
                  _buildTelemetryBadge(
                    icon: Icons.water_drop_outlined,
                    label: 'Ink: ${kiosk.inkStatus}',
                    isOk: kiosk.inkStatus.toUpperCase() != 'LOW',
                  ),
                  const Spacer(),
                  if (isReady)
                    const Row(
                      children: [
                        Text(
                          'Select',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: Color(0xFF2563EB)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryBadge({
    required IconData icon,
    required String label,
    required bool isOk,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isOk ? const Color(0xFF16A34A) : Colors.orange,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isOk ? const Color(0xFF475569) : Colors.orange.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}