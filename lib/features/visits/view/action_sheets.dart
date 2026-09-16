import 'package:flutter/material.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/utils/app_date.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_sheet.dart';
import 'visit_schedule_picker.dart';

/// Bottom sheet asking for a required rejection reason. Returns the reason, or
/// `null` if dismissed.
Future<String?> showRejectReasonSheet(BuildContext context) {
  return showAppSheet<String>(
    context: context,
    builder: (ctx) => AppFormSheet(
      title: ctx.s.wfRejectReason,
      child: _RequiredTextForm(
        hint: ctx.s.wfRejectReasonHint,
        requiredMessage: ctx.s.wfReasonRequired,
        lines: _RequiredTextForm.reasonLines,
        submit: (onPressed) => AppButton.destructive(
          label: ctx.s.wfActionReject,
          onPressed: onPressed,
        ),
      ),
    ),
  );
}

/// Bottom sheet collecting a required outcome to end a visit.
Future<String?> showEndVisitSheet(BuildContext context, {String? initial}) {
  return showAppSheet<String>(
    context: context,
    builder: (ctx) => AppFormSheet(
      title: ctx.s.wfActionEnd,
      child: _RequiredTextForm(
        label: ctx.s.wfFieldOutcome,
        initial: initial,
        requiredMessage: ctx.s.wfOutcomeRequired,
        lines: _RequiredTextForm.outcomeLines,
        submit: (onPressed) => AppButton(
          label: ctx.s.wfActionEnd,
          icon: Icons.stop_circle_outlined,
          onPressed: onPressed,
        ),
      ),
    ),
  );
}

class RescheduleResult {
  final DateTime? scheduled;
  final String? purpose;
  final String? location;
  const RescheduleResult({this.scheduled, this.purpose, this.location});
}

/// Bottom sheet to request a reschedule (date/time, purpose, location).
Future<RescheduleResult?> showRescheduleSheet(
  BuildContext context, {
  DateTime? initialSchedule,
  String? initialPurpose,
  String? initialLocation,
}) {
  return showAppSheet<RescheduleResult>(
    context: context,
    builder: (ctx) => AppFormSheet(
      title: ctx.s.wfRescheduleTitle,
      child: _RescheduleBody(
        initialSchedule: initialSchedule,
        initialPurpose: initialPurpose,
        initialLocation: initialLocation,
      ),
    ),
  );
}

/// A single required text field and its submit button. Pops the sheet with
/// the trimmed text; refuses to submit it blank and says why under the field.
class _RequiredTextForm extends StatefulWidget {
  /// Visible lines for a rejection reason — a sentence or two.
  static const int reasonLines = 3;

  /// Visible lines for a visit outcome — a short report.
  static const int outcomeLines = 4;

  final String? label;
  final String? hint;
  final String? initial;
  final String requiredMessage;
  final int lines;

  /// Builds the submit button around the callback this form owns.
  final Widget Function(VoidCallback onPressed) submit;

  const _RequiredTextForm({
    this.label,
    this.hint,
    this.initial,
    required this.requiredMessage,
    required this.lines,
    required this.submit,
  });

  @override
  State<_RequiredTextForm> createState() => _RequiredTextFormState();
}

class _RequiredTextFormState extends State<_RequiredTextForm> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = widget.requiredMessage);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          maxLines: widget.lines,
          autofocus: true,
          textInputAction: TextInputAction.newline,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            errorText: _error,
            errorMaxLines: widget.lines,
            border: const OutlineInputBorder(),
          ),
        ),
        context.gapH(Insets.x3),
        widget.submit(_submit),
      ],
    );
  }
}

class _RescheduleBody extends StatefulWidget {
  final DateTime? initialSchedule;
  final String? initialPurpose;
  final String? initialLocation;
  const _RescheduleBody({
    this.initialSchedule,
    this.initialPurpose,
    this.initialLocation,
  });

  @override
  State<_RescheduleBody> createState() => _RescheduleBodyState();
}

class _RescheduleBodyState extends State<_RescheduleBody> {
  late DateTime? _scheduled = widget.initialSchedule;
  late final TextEditingController _purpose = TextEditingController(
    text: widget.initialPurpose ?? '',
  );
  late final TextEditingController _location = TextEditingController(
    text: widget.initialLocation ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _purpose.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final picked = await pickVisitSchedule(context, current: _scheduled);
    if (picked == null || !mounted) return;
    setState(() {
      _scheduled = picked;
      _error = null;
    });
  }

  static String? _nonEmpty(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Sends the request, unless nothing differs from the visit as it stands —
  /// the server would accept it and record a reschedule that changes nothing.
  void _submit() {
    final purpose = _nonEmpty(_purpose.text);
    final location = _nonEmpty(_location.text);
    final initial = widget.initialSchedule;
    final scheduled = _scheduled;
    final scheduleChanged =
        scheduled != null &&
        (initial == null || !scheduled.isAtSameMomentAs(initial));
    final changed =
        scheduleChanged ||
        purpose != _nonEmpty(widget.initialPurpose ?? '') ||
        location != _nonEmpty(widget.initialLocation ?? '');
    if (!changed) {
      setState(() => _error = context.s.wfRescheduleNoChanges);
      return;
    }
    Navigator.of(context).pop(
      RescheduleResult(
        scheduled: scheduled,
        purpose: purpose,
        location: location,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = _scheduled;
    final label = scheduled == null
        ? context.s.wfFieldSchedule
        : AppDate.weekdayDateTime(context, scheduled.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _pickDateTime,
          icon: const Icon(Icons.event),
          label: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        context.gapH(Insets.x2h),
        TextField(
          controller: _purpose,
          onChanged: (_) => _clearError(),
          decoration: InputDecoration(
            labelText: context.s.wfFieldPurpose,
            border: const OutlineInputBorder(),
          ),
        ),
        context.gapH(Insets.x2h),
        TextField(
          controller: _location,
          onChanged: (_) => _clearError(),
          decoration: InputDecoration(
            labelText: context.s.wfFieldLocation,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          context.gapH(Insets.x2),
          Text(
            _error!,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.error,
            ),
          ),
        ],
        context.gapH(Insets.x3),
        AppButton(label: context.s.wfActionReschedule, onPressed: _submit),
      ],
    );
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }
}
