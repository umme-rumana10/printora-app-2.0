class PrintJobModel {
  final String id;
  final String machineId;
  final String? fileId;
  final int pages;
  final int copies;
  final bool color;
  final bool duplex;
  final double amount;
  final String status;
  final String? paidAt;
  final String? completedAt;
  final String createdAt;

  PrintJobModel({
    required this.id,
    required this.machineId,
    this.fileId,
    required this.pages,
    required this.copies,
    required this.color,
    required this.duplex,
    required this.amount,
    required this.status,
    this.paidAt,
    this.completedAt,
    required this.createdAt,
  });

  factory PrintJobModel.fromJson(Map<String, dynamic> json) {
    return PrintJobModel(
      id: json['id'] ?? '',
      machineId: json['machine_id'] ?? '',
      fileId: json['file_id'],
      pages: json['pages'] ?? 1,
      copies: json['copies'] ?? 1,
      color: json['color'] ?? false,
      duplex: json['duplex'] ?? false,
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      status: json['status'] ?? 'CREATED',
      paidAt: json['paid_at'],
      completedAt: json['completed_at'],
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}
