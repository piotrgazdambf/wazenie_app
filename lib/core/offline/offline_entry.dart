/// Wpis w lokalnym buforze offline (Hive).
class OfflineEntry {
  final String id;
  final String type;       // 'mcr_zejscie', 'pls_update', 'delivery_create', ...
  final Map<String, dynamic> data;
  final DateTime createdAt;
  String status;            // 'pending', 'sending', 'failed'
  int retryCount;

  OfflineEntry({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.status = 'pending',
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
    'retryCount': retryCount,
  };

  factory OfflineEntry.fromMap(Map<String, dynamic> m) => OfflineEntry(
    id: m['id'] as String,
    type: m['type'] as String,
    data: Map<String, dynamic>.from(m['data'] as Map),
    createdAt: DateTime.parse(m['createdAt'] as String),
    status: m['status'] as String? ?? 'pending',
    retryCount: m['retryCount'] as int? ?? 0,
  );
}
