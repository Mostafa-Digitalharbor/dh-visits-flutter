import '../../../../core/api/odoo_parse.dart';
import '../../../../core/utils/app_number.dart';
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

  static const int _bytesPerKb = 1024;
  static const int _bytesPerMb = _bytesPerKb * _bytesPerKb;

  /// Throws [FormatException] for a row without an id, so `parseRows` skips it.
  factory VisitAttachment.fromJson(Map<String, dynamic> json) =>
      VisitAttachment(
        id:
            odooInt(json['id']) ??
            (throw const FormatException('attachment row without an id')),
        name: odooString(json['name']) ?? '',
        mimetype: odooString(json['mimetype']),
        fileSize: odooInt(json['file_size']) ?? 0,
      );

  /// Human-readable size, e.g. "11 B", "4.2 KB", "1.3 MB" — localized, since
  /// this renders next to the attachment name in the visit detail list.
  ///
  /// Takes the localizations rather than a BuildContext so the model stays
  /// free of widget imports.
  String readableSize(AppLocalizations s) => formatBytes(s, fileSize);

  /// [bytes] in the largest unit that keeps the figure readable. Shared with
  /// the upload size check, so the limit and the rejected file read alike.
  static String formatBytes(AppLocalizations s, int bytes) {
    if (bytes < _bytesPerKb) return s.unitBytes(AppNumber.whole(bytes));
    if (bytes < _bytesPerMb) {
      return s.unitKilobytes(AppNumber.decimal(bytes / _bytesPerKb));
    }
    return s.unitMegabytes(AppNumber.decimal(bytes / _bytesPerMb));
  }
}
