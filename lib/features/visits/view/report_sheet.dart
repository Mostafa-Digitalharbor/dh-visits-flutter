import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../shared/extensions/context_extensions.dart';

enum VisitOutcome { done, postponed, absent }

class ReportResult {
  final VisitOutcome outcome;
  final String notes;
  final bool signed;
  final bool photo;
  const ReportResult(
      {required this.outcome, required this.notes, required this.signed, required this.photo});
}

/// Employee check-out report (design screen 13). Modal bottom sheet collecting
/// outcome + notes + proof photo + client signature before completing the
/// visit. Returns a [ReportResult] (or null if dismissed).
Future<ReportResult?> showReportSheet(BuildContext context) {
  return showModalBottomSheet<ReportResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.40),
    builder: (_) => const ReportSheet(),
  );
}

/// The report sheet content. Normally shown via [showReportSheet]; exposed
/// publicly so the screenshot harness can render it inline.
class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key});

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  VisitOutcome _outcome = VisitOutcome.done;
  final _notesCtrl = TextEditingController();
  final _sigKey = GlobalKey<_SignaturePadState>();
  bool _photo = false;
  bool _signed = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(ReportResult(
      outcome: _outcome,
      notes: _notesCtrl.text.trim(),
      signed: _signed,
      photo: _photo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: x.outlineVariant, borderRadius: BorderRadius.circular(999)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: x.successContainer,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Icon(Symbols.fact_check, fill: 1, size: 22, color: x.success),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(context.s.reportTitle,
                          style: AppType.titleLg.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface)),
                    ),
                    _CloseChip(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    _Label(icon: Symbols.flag, text: context.s.reportOutcome),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _OutcomeTile(
                          icon: Symbols.task_alt,
                          label: context.s.reportOutcomeDone,
                          tone: x.success,
                          selected: _outcome == VisitOutcome.done,
                          onTap: () => setState(() => _outcome = VisitOutcome.done),
                        ),
                        const SizedBox(width: 10),
                        _OutcomeTile(
                          icon: Symbols.event_repeat,
                          label: context.s.reportOutcomePostponed,
                          tone: x.warning,
                          selected: _outcome == VisitOutcome.postponed,
                          onTap: () => setState(() => _outcome = VisitOutcome.postponed),
                        ),
                        const SizedBox(width: 10),
                        _OutcomeTile(
                          icon: Symbols.person_off,
                          label: context.s.reportOutcomeAbsent,
                          tone: cs.error,
                          selected: _outcome == VisitOutcome.absent,
                          onTap: () => setState(() => _outcome = VisitOutcome.absent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _Label(icon: Symbols.edit_note, text: context.s.reportNotes),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(hintText: context.s.reportNotesHint),
                    ),
                    const SizedBox(height: 18),
                    _Label(icon: Symbols.add_a_photo, text: context.s.reportPhoto),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _PhotoTile(added: _photo, onTap: () => setState(() => _photo = !_photo)),
                    ),
                    const SizedBox(height: 18),
                    _Label(icon: Symbols.signature, text: context.s.reportSignature),
                    const SizedBox(height: 8),
                    _SignaturePad(
                      key: _sigKey,
                      onChanged: (has) => setState(() => _signed = has),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.md), boxShadow: x.glowSuccess),
                      child: Material(
                        color: x.success,
                        borderRadius: BorderRadius.circular(Radii.md),
                        child: InkWell(
                          onTap: _submit,
                          borderRadius: BorderRadius.circular(Radii.md),
                          child: Container(
                            height: 56,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Symbols.check_circle, fill: 1, size: 20, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(context.s.reportSubmit,
                                    style: AppType.button.copyWith(
                                        fontWeight: FontWeight.w800, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Label({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.primary),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.onSurface)),
      ],
    );
  }
}

class _OutcomeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tone;
  final bool selected;
  final VoidCallback onTap;
  const _OutcomeTile(
      {required this.icon, required this.label, required this.tone, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: AnimatedContainer(
          duration: AppDurations.base,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? tone.withValues(alpha: 0.14) : cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: selected ? tone : x.outlineVariant, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, fill: selected ? 1 : 0, size: 26, color: selected ? tone : cs.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? tone : cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final bool added;
  final VoidCallback onTap;
  const _PhotoTile({required this.added, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        height: 84,
        width: 84,
        decoration: BoxDecoration(
          color: added ? x.successContainer : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: added ? x.success : x.outlineVariant,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(added ? Symbols.check_circle : Symbols.photo_camera,
                fill: 1, size: 24, color: added ? x.success : x.textTertiary),
            const SizedBox(height: 6),
            Text(added ? '✓' : context.s.reportAddPhoto,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: x.textTertiary)),
          ],
        ),
      ),
    );
  }
}

/// Lightweight signature pad — captures strokes via [CustomPainter], no
/// external package. Reports whether anything has been drawn.
class _SignaturePad extends StatefulWidget {
  final ValueChanged<bool> onChanged;
  const _SignaturePad({super.key, required this.onChanged});

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  final List<List<Offset>> _strokes = [];

  void _clear() {
    setState(_strokes.clear);
    widget.onChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final empty = _strokes.isEmpty;
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: x.outlineVariant, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GestureDetector(
            onPanStart: (d) {
              setState(() => _strokes.add([d.localPosition]));
              if (_strokes.length == 1) widget.onChanged(true);
            },
            onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
            child: CustomPaint(
              painter: _SigPainter(_strokes, cs.onSurface),
              size: Size.infinite,
            ),
          ),
          if (empty)
            IgnorePointer(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Symbols.draw, size: 18, color: x.textTertiary),
                    const SizedBox(width: 6),
                    Text(context.s.reportSignHere,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: x.textTertiary)),
                  ],
                ),
              ),
            ),
          if (!empty)
            PositionedDirectional(
              end: 6,
              top: 6,
              child: TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Symbols.ink_eraser, size: 16),
                label: Text(context.s.reportClear),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ),
        ],
      ),
    );
  }
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  _SigPainter(this.strokes, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      for (var i = 1; i < stroke.length; i++) {
        canvas.drawLine(stroke[i - 1], stroke[i], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SigPainter old) => true;
}

class _CloseChip extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Symbols.close, size: 20, color: cs.onSurfaceVariant),
      ),
    );
  }
}
