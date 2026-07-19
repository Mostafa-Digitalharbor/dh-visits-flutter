import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../data/models/visit_attachment.dart';
import '../data/visits_repository.dart';
import 'visit_section.dart';
import '../../../app/design/app_dimens.dart';

/// The visit's file list, with tap-to-open.
///
/// [attachments] comes from `VisitDetailState` rather than being fetched here:
/// this section used to build a `FutureBuilder` whose future was constructed
/// inside `build()`, so it re-hit Odoo on every rebuild.
class VisitAttachmentsSection extends StatelessWidget {
  final List<VisitAttachment> attachments;

  /// Attachments fail independently of the visit, so the error renders in
  /// place instead of blanking the screen.
  final ApiException? error;

  const VisitAttachmentsSection({
    super.key,
    required this.attachments,
    this.error,
  });

  IconData _iconFor(String? mimetype) {
    final m = mimetype ?? '';
    if (m.startsWith('image/')) return Icons.image_outlined;
    if (m.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (m.startsWith('video/')) return Icons.videocam_outlined;
    if (m.startsWith('audio/')) return Icons.audiotrack_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _openAttachment(BuildContext context, VisitAttachment a) async {
    context.showSnack(context.s.commonLoading);
    try {
      final b64 = await sl<VisitsRepository>().downloadAttachmentB64(a.id);
      if (b64 == null || b64.isEmpty) {
        if (context.mounted) {
          context.showSnack(context.s.errAttachmentUnavailable,
              kind: SnackKind.error);
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      // basename: the name is server-supplied, and one containing a path
      // separator would otherwise write outside the temp directory.
      final file = File(p.join(dir.path, p.basename(a.name)));
      await file.writeAsBytes(base64Decode(b64));
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && context.mounted) {
        context.showSnack(context.s.errAttachmentOpenFailed,
            kind: SnackKind.error);
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        context.showSnack(e.localize(context), kind: SnackKind.error);
      }
    } catch (_) {
      if (context.mounted) {
        context.showSnack(context.s.errAttachmentOpenFailed,
            kind: SnackKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return VisitSection(
      icon: Icons.attach_file,
      title: context.s.wfActionAddAttachment,
      rows: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.s.errAttachmentsLoadFailed,
                    style: context.text.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
              ],
            ),
          )
        else if (attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              context.s.attachmentsEmpty,
              style:
                  context.text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          )
        else
          for (final a in attachments)
            InkWell(
              borderRadius: BorderRadius.circular(Radii.tile),
              onTap: () => _openAttachment(context, a),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Radii.tile),
                      ),
                      child: Icon(_iconFor(a.mimetype),
                          size: 19, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.readableSize(context.s),
                            style: context.text.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.download_outlined, size: 20, color: cs.tertiary),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
