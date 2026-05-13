import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../data/models/visit.dart';

/// Human-readable label for a lifecycle state. All four real Odoo
/// states are surfaced distinctly now — `underReview` no longer hides
/// behind "Submit" because admins need to spot visits awaiting their
/// sign-off.
String lifecycleStateLabel(BuildContext context, VisitLifecycleState s) {
  switch (s) {
    case VisitLifecycleState.draft:
      return context.s.visitStateDraft;
    case VisitLifecycleState.submit:
      return context.s.visitStateSubmit;
    case VisitLifecycleState.underReview:
      return context.s.visitStateUnderReview;
    case VisitLifecycleState.done:
      return context.s.visitStateDone;
    case VisitLifecycleState.cancel:
      return context.s.visitStateCancel;
    case VisitLifecycleState.unknown:
      return '-';
  }
}

/// Bottom-sheet picker that lets the admin pick a visit's lifecycle
/// state. By default all four real states (Draft / Submit / Under
/// Review / Done) are offered, but callers can pass `allowedStates` to
/// narrow the menu — used to enforce the workflow rule that you can't
/// jump-ahead to a state that requires actual work to have happened:
///
///   • Create-visit & not-yet-started visits → [draft, submit]
///   • Visits the employee has already checked-out → [underReview, done]
///
/// Returns `null` if dismissed.
Future<VisitLifecycleState?> showLifecycleStatePicker(
  BuildContext context, {
  required VisitLifecycleState current,
  List<VisitLifecycleState>? allowedStates,
}) {
  const allOptions = [
    (VisitLifecycleState.draft, Icons.edit_note_rounded),
    (VisitLifecycleState.submit, Icons.play_arrow_rounded),
    (VisitLifecycleState.underReview, Icons.rate_review_rounded),
    (VisitLifecycleState.done, Icons.check_circle_rounded),
  ];
  final allowed = allowedStates;
  final options = allowed == null
      ? allOptions
      : allOptions.where((o) => allowed.contains(o.$1)).toList();
  return showModalBottomSheet<VisitLifecycleState>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              ctx.s.visitDetailPickState,
              style: ctx.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final option in options)
            ListTile(
              leading: Icon(option.$2, color: ctx.colors.primary),
              title: Text(lifecycleStateLabel(ctx, option.$1)),
              trailing: option.$1 == current
                  ? Icon(Icons.check_rounded, color: ctx.colors.primary)
                  : null,
              onTap: () => Navigator.of(ctx).pop(option.$1),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
