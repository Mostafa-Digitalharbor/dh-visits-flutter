import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_button.dart';

/// Bottom sheet asking for a required rejection reason. Returns the reason, or
/// `null` if dismissed.
Future<String?> showRejectReasonSheet(BuildContext context) {
  return _showFormSheet<String>(
    context: context,
    title: context.s.wfRejectReason,
    builder: (ctx, submit) => _RejectReasonBody(onSubmit: submit),
  );
}

/// Bottom sheet collecting a required outcome to end a visit.
Future<String?> showEndVisitSheet(BuildContext context, {String? initial}) {
  return _showFormSheet<String>(
    context: context,
    title: context.s.wfActionEnd,
    builder: (ctx, submit) =>
        _OutcomeBody(onSubmit: submit, initial: initial),
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
  return _showFormSheet<RescheduleResult>(
    context: context,
    title: context.s.wfRescheduleTitle,
    builder: (ctx, submit) => _RescheduleBody(
      onSubmit: submit,
      initialSchedule: initialSchedule,
      initialPurpose: initialPurpose,
      initialLocation: initialLocation,
    ),
  );
}

Future<T?> _showFormSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext, void Function(T)) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: ctx.text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          builder(ctx, (v) => Navigator.of(ctx).pop(v)),
        ],
      ),
    ),
  );
}

class _RejectReasonBody extends StatefulWidget {
  final void Function(String) onSubmit;
  const _RejectReasonBody({required this.onSubmit});

  @override
  State<_RejectReasonBody> createState() => _RejectReasonBodyState();
}

class _RejectReasonBodyState extends State<_RejectReasonBody> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = context.s.wfReasonRequired);
      return;
    }
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.s.wfRejectReasonHint,
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        AppButton.destructive(
          label: context.s.wfActionReject,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _OutcomeBody extends StatefulWidget {
  final void Function(String) onSubmit;
  final String? initial;
  const _OutcomeBody({required this.onSubmit, this.initial});

  @override
  State<_OutcomeBody> createState() => _OutcomeBodyState();
}

class _OutcomeBodyState extends State<_OutcomeBody> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial ?? '');
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = context.s.wfOutcomeRequired);
      return;
    }
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.s.wfFieldOutcome,
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: context.s.wfActionEnd,
          icon: Icons.stop_circle_outlined,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _RescheduleBody extends StatefulWidget {
  final void Function(RescheduleResult) onSubmit;
  final DateTime? initialSchedule;
  final String? initialPurpose;
  final String? initialLocation;
  const _RescheduleBody({
    required this.onSubmit,
    this.initialSchedule,
    this.initialPurpose,
    this.initialLocation,
  });

  @override
  State<_RescheduleBody> createState() => _RescheduleBodyState();
}

class _RescheduleBodyState extends State<_RescheduleBody> {
  late DateTime? _scheduled = widget.initialSchedule;
  late final TextEditingController _purpose =
      TextEditingController(text: widget.initialPurpose ?? '');
  late final TextEditingController _location =
      TextEditingController(text: widget.initialLocation ?? '');

  @override
  void dispose() {
    _purpose.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final base = _scheduled?.toLocal() ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!mounted) return;
    final t = time ?? TimeOfDay.fromDateTime(base);
    setState(() {
      _scheduled = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = _scheduled == null
        ? context.s.wfFieldSchedule
        : '${_scheduled!.toLocal()}'.split('.').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _pickDateTime,
          icon: const Icon(Icons.event),
          label: Text(label),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _purpose,
          decoration: InputDecoration(
            labelText: context.s.wfFieldPurpose,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _location,
          decoration: InputDecoration(
            labelText: context.s.wfFieldLocation,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: context.s.wfActionReschedule,
          onPressed: () => widget.onSubmit(RescheduleResult(
            scheduled: _scheduled,
            purpose: _purpose.text.trim().isEmpty ? null : _purpose.text.trim(),
            location:
                _location.text.trim().isEmpty ? null : _location.text.trim(),
          )),
        ),
      ],
    );
  }
}
