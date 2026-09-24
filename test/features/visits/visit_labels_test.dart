import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_participant.dart';
import 'package:location_gps/features/visits/view/visit_labels.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';
import 'package:location_gps/shared/widgets/widgets.dart';

import '../../widgets/widget_harness.dart';

/// The label each state must show — spelled out here rather than derived, so
/// a swapped case in the widget fails the test.
String _expectedLabel(AppLocalizations t, VisitState state) => switch (state) {
      VisitState.draft => t.wfStateDraft,
      VisitState.submitted => t.wfStateSubmitted,
      VisitState.waitingParticipantManagerApproval =>
        t.wfStateWaitingParticipant,
      VisitState.waitingDirectManagerApproval => t.wfStateWaitingManager,
      VisitState.escalated => t.wfStateEscalated,
      VisitState.approved => t.wfStateApproved,
      VisitState.rejected => t.wfStateRejected,
      VisitState.cancelled => t.wfStateCancelled,
      VisitState.rescheduleRequested => t.wfStateReschedule,
      VisitState.inProgress => t.wfStateInProgress,
      VisitState.done => t.wfStateDone,
      VisitState.unknown => t.wfStateUnknown,
    };

Color _expectedColor(BuildContext context, VisitState state) {
  final cs = Theme.of(context).colorScheme;
  final x = context.x;
  return switch (state) {
    VisitState.draft || VisitState.unknown => cs.outline,
    VisitState.submitted ||
    VisitState.waitingParticipantManagerApproval ||
    VisitState.waitingDirectManagerApproval ||
    VisitState.rescheduleRequested =>
      x.warning,
    VisitState.escalated || VisitState.rejected || VisitState.cancelled =>
      cs.error,
    VisitState.approved => x.info,
    VisitState.inProgress => x.success,
    VisitState.done => x.onSuccessContainer,
  };
}

/// A context from a pumped tree, for the helpers that need one.
Future<BuildContext> _context(WidgetTester tester, Surface s) async {
  await pumpSurface(tester, s, const SizedBox(key: Key('probe')));
  return tester.element(find.byKey(const Key('probe')));
}

void main() {
  setUpAll(initHarness);

  group('VisitStateBadge', () {
    testOnEverySurface(
      'every state side by side',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final state in VisitState.values)
              VisitStateBadge(state, key: ValueKey(state)),
          ],
        ),
      ),
      verify: (tester, s) async {
        final t = l10n(s.locale);
        for (final state in VisitState.values) {
          final badge = find.byKey(ValueKey(state));
          expect(
            find.descendant(
                of: badge, matching: find.text(_expectedLabel(t, state))),
            findsOneWidget,
            reason: '$state',
          );
        }
      },
    );

    for (final s in const [phoneEn, phoneAr]) {
      testWidgets('each state has its own label and tone — ${s.name}',
          (tester) async {
        await pumpSurface(
          tester,
          s,
          Wrap(children: [
            for (final state in VisitState.values)
              VisitStateBadge(state, key: ValueKey(state)),
          ]),
        );
        final context = tester.element(find.byType(Wrap));
        final t = l10n(s.locale);
        final labels = <String>{};
        for (final state in VisitState.values) {
          final pill = tester.widget<TonePill>(find.descendant(
              of: find.byKey(ValueKey(state)),
              matching: find.byType(TonePill)));
          expect(pill.label, _expectedLabel(t, state), reason: '$state');
          expect(pill.color, _expectedColor(context, state), reason: '$state');
          expect(pill.label, isNotEmpty);
          labels.add(pill.label);
        }
        expect(labels, hasLength(VisitState.values.length),
            reason: 'no two states read the same');
      });
    }

    testWidgets('dark mode resolves the dark tones', (tester) async {
      const dark = Surface('dark', size: Size(390, 844), locale: english,
          brightness: Brightness.dark);
      await pumpSurface(
          tester, dark, const VisitStateBadge(VisitState.inProgress));
      final context = tester.element(find.byType(VisitStateBadge));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(tester.widget<TonePill>(find.byType(TonePill)).color,
          AppTheme.dark().extension<AppX>()!.success);
    });

    testWidgets('outside the app theme the brand hues stand in',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: english,
        home: const Wrap(children: [
          VisitStateBadge(VisitState.inProgress, key: Key('run')),
          VisitStateBadge(VisitState.done, key: Key('done')),
          VisitStateBadge(VisitState.submitted, key: Key('wait')),
          VisitStateBadge(VisitState.approved, key: Key('ok')),
        ]),
      ));
      Color colorOf(String key) => tester
          .widget<TonePill>(find.descendant(
              of: find.byKey(Key(key)), matching: find.byType(TonePill)))
          .color;
      expect(colorOf('run'), AppColors.green);
      expect(colorOf('done'), AppColors.green);
      expect(colorOf('wait'), AppColors.amber);
      expect(colorOf('ok'), AppColors.teal500);
      expect(tester.takeException(), isNull);
    });
  });

  group('VisitDisplay', () {
    testWidgets('title: customer, then reference, then "Visit #id"',
        (tester) async {
      for (final s in const [phoneEn, phoneAr]) {
        final context = await _context(tester, s);
        final t = l10n(s.locale);
        expect(
          const Visit(id: 12, name: 'VIS/12', partnerName: 'Acme')
              .displayTitle(context),
          'Acme',
        );
        expect(const Visit(id: 12, name: 'VIS/12').displayTitle(context),
            'VIS/12');
        expect(const Visit(id: 12).displayTitle(context),
            t.visitFallbackTitle(12));
        // Empty strings are values, not gaps: the server sends `false`,
        // which the parser already turns into null.
        expect(const Visit(id: 12, partnerName: '').displayTitle(context), '');
      }
    });

    testWidgets('reference: the name, else "Visit #id"', (tester) async {
      final context = await _context(tester, phoneAr);
      expect(
        const Visit(id: 3, name: 'VIS/3', partnerName: 'Acme')
            .displayReference(context),
        'VIS/3',
      );
      expect(const Visit(id: 3, partnerName: 'Acme').displayReference(context),
          l10n(arabic).visitFallbackTitle(3));
      expect(const Visit(id: 0).displayReference(context),
          l10n(arabic).visitFallbackTitle(0));
      expect(const Visit(id: 987654321).displayTitle(context),
          l10n(arabic).visitFallbackTitle(987654321));
    });
  });

  group('labels and tones', () {
    testWidgets('visit types, unknown reads empty', (tester) async {
      final context = await _context(tester, phoneEn);
      final t = l10n(english);
      expect(visitTypeLabel(context, VisitType.project), t.wfTypeProject);
      expect(visitTypeLabel(context, VisitType.opportunity),
          t.wfTypeOpportunity);
      expect(visitTypeLabel(context, VisitType.unknown), '');
    });

    testWidgets('participant states have labels and tones', (tester) async {
      final context = await _context(tester, phoneAr);
      final t = l10n(arabic);
      final cs = Theme.of(context).colorScheme;
      final x = context.x;
      const states = ParticipantApprovalState.values;
      expect(
        [for (final s in states) participantStateLabel(context, s)],
        [
          t.wfParticipantPending,
          t.wfParticipantApprovedState,
          t.wfParticipantRejectedState,
          t.wfStateUnknown,
        ],
      );
      expect(
        [for (final s in states) participantStateColor(context, s)],
        [x.warning, x.success, cs.error, cs.outline],
      );
    });

    testWidgets('the tone getters read the theme extension', (tester) async {
      final context = await _context(tester, phoneEn);
      final x = context.x;
      expect(context.visitSuccess, x.success);
      expect(context.visitSettled, x.onSuccessContainer);
      expect(context.visitWarning, x.warning);
      expect(context.visitInfo, x.info);
    });

    testWidgets('visitStateColor and visitStateLabel agree with the badge',
        (tester) async {
      final context = await _context(tester, phoneEn);
      for (final state in VisitState.values) {
        expect(visitStateColor(context, state), _expectedColor(context, state));
        expect(visitStateLabel(context, state),
            _expectedLabel(l10n(english), state));
      }
    });
  });
}
