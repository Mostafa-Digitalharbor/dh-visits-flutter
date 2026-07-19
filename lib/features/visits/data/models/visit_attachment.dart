import '../../../../l10n/generated/app_localizations.dart';

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

  /// Human-readable size, e.g. "11 B", "4.2 KB", "1.3 MB" — localized, since
  /// this renders next to the attachment name in the visit detail list.
  ///
  /// Takes the localizations rather than a BuildContext so the model stays
  /// free of widget imports.
  String readableSize(AppLocalizations s) {
    const kb = 1024;
    const mb = kb * 1024;
    if (fileSize < kb) return s.unitBytes('$fileSize');
    if (fileSize < mb) return s.unitKilobytes((fileSize / kb).toStringAsFixed(1));
    return s.unitMegabytes((fileSize / mb).toStringAsFixed(1));
  }
}
