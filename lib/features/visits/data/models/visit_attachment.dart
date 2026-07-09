/// A file attached to a visit (`ir.attachment` linked via
/// `res_model='dh.visit'`, `res_id=<visit>`).
class VisitAttachment {
  final int id;
  final String name;
  final String? mimetype;
  final int fileSize;

  const VisitAttachment({
    required this.id,
    required this.name,
    this.mimetype,
    this.fileSize = 0,
  });

  factory VisitAttachment.fromJson(Map<String, dynamic> json) => VisitAttachment(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        mimetype: (json['mimetype'] == false) ? null : json['mimetype']?.toString(),
        fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      );

  /// Human-readable size, e.g. "11 B", "4.2 KB", "1.3 MB".
  String get readableSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
