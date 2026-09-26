class KioskModel {
  final String id;
  final String location;
  final String status;
  final String paperStatus;
  final String inkStatus;
  final String printerStatus;
  final bool maintenanceMode;

  KioskModel({
    required this.id,
    required this.location,
    required this.status,
    required this.paperStatus,
    required this.inkStatus,
    required this.printerStatus,
    required this.maintenanceMode,
  });

  bool get isReady =>
      status == 'ONLINE' &&
      paperStatus != 'OUT' &&
      printerStatus != 'ERROR' &&
      !maintenanceMode;

  factory KioskModel.fromJson(Map<String, dynamic> json) {
    return KioskModel(
      id: json['id'] ?? '',
      location: json['location'] ?? 'Unknown Location',
      status: json['status'] ?? 'OFFLINE',
      paperStatus: json['paper_status'] ?? 'OK',
      inkStatus: json['ink_status'] ?? 'OK',
      printerStatus: json['printer_status'] ?? 'IDLE',
      maintenanceMode: json['maintenance_mode'] ?? false,
    );
  }
}
