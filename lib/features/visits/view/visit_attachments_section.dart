import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/attachment_upload.dart';
import '../data/models/visit_attachment.dart';
import '../data/visits_repository.dart';
import 'visit_section.dart';

/// The visit's file list, with tap-to-open.
///
/// [attachments] comes from `VisitDetailState` rather than being fetched here:
/// this section used to build a `FutureBuilder` whose future was constructed
/// inside `build()`, so it re-hit Odoo on every rebuild.
class VisitAttachmentsSection extends StatefulWidget {
  final List<VisitAttachment> attachments;

  /// Attachments fail independently of the visit, so the error renders in
  /// place instead of blanking the screen.
  final ApiException? error;

  const VisitAttachmentsSection({
    super.key,
    required this.attachments,
    this.error,
  });

  @override
  State<VisitAttachmentsSection> createState() =>
      _VisitAttachmentsSectionState();
}

class _VisitAttachmentsSectionState extends State<VisitAttachmentsSection> {
  /// Attachments being downloaded. Their row shows progress and ignores taps:
  /// each tap used to start another full download of the same file.
  final Set<int> _opening = {};

  /// Stroke of the small spinner that replaces a row's download glyph — thin
  /// enough to sit in a 20dp box.
  static const double _progressStroke = 2;

  static IconData _iconFor(String? mimetype) {
    final m = mimetype ?? '';
    if (m.startsWith('image/')) return Icons.image_outlined;
    if (m.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (m.startsWith('video/')) return Icons.videocam_outlined;
    if (m.startsWith('audio/')) return Icons.audiotrack_outlined;
    return Icons.insert_drive_file_outlined;
  }

  /// A temp-file name that is unique per attachment. The id prefix keeps two
  /// attachments called `photo.jpg` from overwriting each other, and
  /// `basename` keeps a server-supplied name containing a path separator from
  /// writing outside the temp directory.
  static String _fileName(VisitAttachment a) {
    final base = p.basename(a.name);
    return base.isEmpty ? '${a.id}' : '${a.id}_$base';
  }

  Future<void> _open(VisitAttachment a) async {
    if (!_opening.add(a.id)) return;
    setState(() {});
    try {
      await _download(a);
    } finally {
      if (mounted) setState(() => _opening.remove(a.id));
    }
  }

  Future<void> _download(VisitAttachment a) async {
    final s = context.s;
    try {
      final b64 = await sl<VisitsRepository>().downloadAttachmentB64(a.id);
      if (!mounted) return;
      if (b64 == null) {
        context.showSnack(s.errAttachmentUnavailable, kind: SnackKind.error);
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, _fileName(a));
      await writeAttachment(path, b64);
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        context.showSnack(s.errAttachmentOpenFailed, kind: SnackKind.error);
      }
    } on ApiException catch (e) {
      if (mounted) {
        context.showSnack(e.localize(context), kind: SnackKind.error);
      }
    } catch (_) {
      if (mounted) {
        context.showSnack(s.errAttachmentOpenFailed, kind: SnackKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final attachments = widget.attachments;
    return VisitSection(
      icon: Icons.attach_file,
      title: context.s.wfSectionAttachments,
      rows: [
        if (widget.error != null)
          _ErrorRow(message: context.s.errAttachmentsLoadFailed)
        else if (attachments.isEmpty)
          InlineEmptyRow(text: context.s.attachmentsEmpty)
        else
          for (final a in attachments)
            InkWell(
              borderRadius: BorderRadius.circular(Radii.tile),
              onTap: _opening.contains(a.id) ? null : () => _open(a),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.r(Insets.x2h)),
                child: MediaRow(
                  trailingGap: Insets.x2,
                  leading: IconBadge(
                    icon: _iconFor(a.mimetype),
                    color: cs.primary,
                    size: context.r(CompSz.badge),
                    iconSize: context.r(IconSz.label),
                  ),
                  lines: [
                    Text(
                      a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    context.gapH(Insets.hair),
                    Text(
                      a.readableSize(context.s),
                      maxLines: 1,
                      style: context.text.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  // Same footprint whether it is the download affordance or
                  // the spinner that replaces it, so the row does not twitch
                  // when a tap starts the download.
                  trailing: SizedBox.square(
                    dimension: context.r(IconSz.sm),
                    child: _opening.contains(a.id)
                        ? const CircularProgressIndicator(
                            strokeWidth: _progressStroke,
                          )
                        : Icon(
                            Icons.download_outlined,
                            size: context.r(IconSz.sm),
                            color: cs.tertiary,
                          ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// The in-card failure line, in the error colour so it doesn't read as an
/// empty list.
class _ErrorRow extends StatelessWidget {
  final String message;
  const _ErrorRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final error = context.colors.error;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.r(Insets.x2h)),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: context.r(IconSz.label),
            color: error,
          ),
          context.gapW(Insets.x2),
          Expanded(
            child: Text(
              message,
              style: context.text.bodySmall?.copyWith(color: error),
            ),
          ),
        ],
      ),
    );
  }
}
