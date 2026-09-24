import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/utils/app_date.dart';
import 'package:location_gps/features/auth/bloc/auth_bloc.dart';
import 'package:location_gps/features/auth/data/auth_repository.dart';
import 'package:location_gps/features/auth/data/models/user.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/view/visit_labels.dart';
import 'package:location_gps/shared/widgets/tone_pill.dart';
import 'package:location_gps/shared/widgets/visit_card.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:location_gps/shared/extensions/context_extensions.dart';

import 'widget_harness.dart';

/// Local wall-clock time, so the expected text doesn't depend on the zone
/// the test runs in (no signed-in user → the device zone is used).
final DateTime _schedule = DateTime(2026, 7, 15, 14, 30);

const _longPurpose =
    'Follow up on phase two delivery, review the revised timeline with the '
    'site manager, collect the signed handover documents and photograph the '
    'installed equipment for the quarterly report.';

Visit _full(Surface s, {VisitState state = VisitState.waitingDirectManagerApproval}) =>
    Visit(
      id: 12,
      name: 'VIS/2026/00012',
      visitType: VisitType.project,
      projectName: LongText.of(s),
      partnerName: s.isArabic ? LongText.arabicCompany : LongText.english,
      employeeName: s.isArabic
          ? LongText.arabicPerson
          : 'Maximilian Alexander Konstantinopoulos-Worthington',
      scheduledDatetime: _schedule,
      purpose: s.isArabic ? '${LongText.arabicCompany} ' * 3 : _longPurpose,
      isEscalated: true,
      state: state,
    );

Widget _card(
  Visit visit, {
  VoidCallback? onTap,
  bool showEmployee = false,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VisitCard(visit: visit, onTap: onTap, showEmployee: showEmployee),
    );

class _FakeAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _SignedIn extends AuthBloc {
  _SignedIn(String tz) : super(repository: _FakeAuthRepo()) {
    emit(AuthState.authenticated(
      AuthUser(uid: 2, username: 'rep@example.com', tz: tz),
    ));
  }

  @override
  void add(AuthEvent event) {}
}

/// What the card should print for [when]: whatever [AppDate] formats in the
/// card's own locale (the pattern itself is AppDate's to decide).
String _expectedSchedule(WidgetTester tester, DateTime when) =>
    AppDate.dateTime(tester.element(find.byType(VisitCard)), when);

/// The text of the meta line next to [icon].
Finder _metaText(IconData icon) => find.descendant(
      of: find.ancestor(of: find.byIcon(icon), matching: find.byType(Row)).first,
      matching: find.byType(Text),
    );

void main() {
  setUpAll(() async {
    await initHarness();
    tz_data.initializeTimeZones();
  });

  group('VisitCard layout', () {
    testOnEverySurface(
      'long names, every part present, showEmployee',
      (s) => _card(_full(s), onTap: () {}, showEmployee: true),
      verify: (tester, s) async {
        final title = tester.renderObject<RenderParagraph>(
          find.text(s.isArabic ? LongText.arabicCompany : LongText.english),
        );
        expect(title.maxLines, 1);
        expect(title.didExceedMaxLines, isTrue);
        final purpose = tester.widget<Text>(find.byWidgetPredicate(
          (w) => w is Text && w.maxLines == 2,
        ));
        expect(purpose.overflow, TextOverflow.ellipsis);
      },
    );

    testOnEverySurface(
      'every workflow state badge fits beside a long customer',
      (s) => Column(
        children: [
          for (final state in VisitState.values)
            _card(_full(s, state: state), showEmployee: true),
        ],
      ),
      scrollable: true,
      verify: (tester, s) async {
        expect(find.byType(VisitStateBadge),
            findsNWidgets(VisitState.values.length));
        final screen = s.size.width;
        for (final e in find.byType(VisitStateBadge).evaluate()) {
          final badge = tester.getSize(find.byWidget(e.widget));
          expect(badge.width, lessThanOrEqualTo(screen * 0.45 + 0.01));
        }
      },
    );

    testOnEverySurface(
      'a bare visit (id only) and an opportunity without a customer fit',
      (s) => Column(
        children: [
          _card(const Visit(id: 7)),
          _card(Visit(
            id: 8,
            name: 'VIS/2026/00008',
            visitType: VisitType.opportunity,
            opportunityName: 'W' * 80,
          )),
        ],
      ),
    );
  });

  group('VisitCard title and reference', () {
    testWidgets('the customer is the title, the reference sits under it',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _card(const Visit(id: 3, name: 'VIS/2026/00003', partnerName: 'Acme')),
      );
      final title = tester.getRect(find.text('Acme'));
      final ref = tester.getRect(find.text('VIS/2026/00003'));
      expect(ref.top, greaterThanOrEqualTo(title.bottom));
      final context = tester.element(find.byType(VisitCard));
      expect(
        tester.widget<Text>(find.text('VIS/2026/00003')).style?.color,
        Theme.of(context).colorScheme.outline,
      );
    });

    testWidgets('without a customer the reference is the title, shown once',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _card(const Visit(id: 3, name: 'VIS/2026/00003')),
      );
      expect(find.text('VIS/2026/00003'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('VIS/2026/00003')).style?.fontWeight,
        FontWeight.w700,
      );
    });

    for (final surface in [phoneEn, phoneAr]) {
      testWidgets('with neither, the localized fallback title — $surface',
          (tester) async {
        await pumpSurface(tester, surface, _card(const Visit(id: 42)));
        final expected = l10n(surface.locale).visitFallbackTitle(42);
        expect(find.text(expected), findsOneWidget);
        expect(expected, surface.isArabic ? 'زيارة رقم 42' : 'Visit #42');
        // Nothing else to show: just the title row and the badge.
        expect(find.byIcon(Icons.schedule), findsNothing);
        expect(find.byIcon(Icons.person_outline), findsNothing);
        expect(find.byIcon(Icons.priority_high_rounded), findsNothing);
      });
    }

    testWidgets('a visit with no type or linked record has no empty meta line',
        (tester) async {
      await pumpSurface(tester, phoneEn, _card(const Visit(id: 42)));
      expect(find.byIcon(Icons.folder_open_outlined), findsNothing);
      expect(find.text(''), findsNothing);
    });

    testWidgets('in Arabic the title leads from the right, the badge trails',
        (tester) async {
      final visit = _full(phoneAr);
      await pumpSurface(tester, phoneAr, _card(visit));
      final title = tester.getRect(find.text(LongText.arabicCompany).first);
      final badge = tester.getRect(find.byType(VisitStateBadge));
      expect(badge.right, lessThanOrEqualTo(title.left));

      await pumpSurface(tester, phoneEn, _card(_full(phoneEn)));
      final enTitle = tester.getRect(find.text(LongText.english).first);
      final enBadge = tester.getRect(find.byType(VisitStateBadge));
      expect(enBadge.left, greaterThanOrEqualTo(enTitle.right));
    });

    testWidgets('the badge shows the localized state', (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        _card(const Visit(id: 1, state: VisitState.inProgress)),
      );
      expect(find.text(l10n(arabic).wfStateInProgress), findsOneWidget);
      expect(find.byType(TonePill), findsOneWidget);
    });
  });

  group('VisitCard facts', () {
    for (final surface in [phoneEn, phoneAr]) {
      testWidgets('project type and name, joined — $surface', (tester) async {
        final t = l10n(surface.locale);
        await pumpSurface(
          tester,
          surface,
          _card(const Visit(
            id: 1,
            visitType: VisitType.project,
            projectName: 'Tower B',
            opportunityName: 'ignored',
          )),
        );
        expect(
          find.text('${t.wfTypeProject}${t.commonListSeparator}'
              '${bidiIsolateIfForeign('Tower B', rtl: surface.isArabic)}'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
      });

      testWidgets('opportunity type and name, joined — $surface',
          (tester) async {
        final t = l10n(surface.locale);
        await pumpSurface(
          tester,
          surface,
          _card(const Visit(
            id: 1,
            visitType: VisitType.opportunity,
            projectName: 'ignored',
            opportunityName: 'Fit-out deal',
          )),
        );
        expect(
          find.text('${t.wfTypeOpportunity}${t.commonListSeparator}'
              '${bidiIsolateIfForeign('Fit-out deal', rtl: surface.isArabic)}'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
      });
    }

    testWidgets('a type without a linked record shows the type alone',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _card(const Visit(id: 1, visitType: VisitType.project)),
      );
      expect(find.text(l10n(english).wfTypeProject), findsOneWidget);
    });

    testWidgets('a long linked name ellipsizes on its line', (tester) async {
      await pumpSurface(
        tester,
        surfaces[0],
        _card(Visit(
          id: 1,
          visitType: VisitType.project,
          projectName: LongText.arabicCompany,
        )),
      );
      expectCleanLayout(tester);
      final text = tester.renderObject<RenderParagraph>(
        _metaText(Icons.folder_open_outlined),
      );
      expect(text.maxLines, 1);
      expect(text.didExceedMaxLines, isTrue);
    });

    for (final (surface, name) in [
      (phoneEn, 'Sara Al-Qahtani'),
      (phoneAr, LongText.arabicPerson),
    ]) {
      testWidgets('showEmployee adds the responsible employee — $surface',
          (tester) async {
        final visit = Visit(id: 1, employeeName: name);
        await pumpSurface(tester, surface, _card(visit, showEmployee: true));
        expect(find.text(name), findsOneWidget);
        expect(find.byIcon(Icons.person_outline), findsOneWidget);

        await pumpSurface(tester, surface, _card(visit));
        expect(find.text(name), findsNothing);
        expect(find.byIcon(Icons.person_outline), findsNothing);
      });
    }

    testWidgets('showEmployee without an employee shows nothing',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _card(const Visit(id: 1), showEmployee: true),
      );
      expect(find.byIcon(Icons.person_outline), findsNothing);
    });

    testWidgets('the purpose shows under the facts, two lines at most',
        (tester) async {
      await pumpSurface(
        tester,
        surfaces[1],
        _card(Visit(
          id: 1,
          visitType: VisitType.project,
          projectName: 'Tower B',
          purpose: _longPurpose,
        )),
      );
      final purpose = tester.renderObject<RenderParagraph>(
        find.text(_longPurpose),
      );
      expect(purpose.maxLines, 2);
      expect(purpose.didExceedMaxLines, isTrue);
      expect(
        tester.getRect(find.text(_longPurpose)).top,
        greaterThan(tester.getRect(find.byIcon(Icons.folder_open_outlined)).bottom),
      );
    });

    testWidgets('no purpose, no purpose line', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _card(const Visit(id: 1, partnerName: 'Acme')),
      );
      expect(
        find.byWidgetPredicate((w) => w is Text && w.maxLines == 2),
        findsNothing,
      );
    });
  });

  group('VisitCard escalation highlight', () {
    for (final surface in [phoneEn, phoneAr, surfaces[2]]) {
      testWidgets('an escalated visit is flagged in the error colour — '
          '$surface', (tester) async {
        await pumpSurface(
          tester,
          surface,
          _card(const Visit(id: 1, isEscalated: true)),
        );
        final error =
            Theme.of(tester.element(find.byType(VisitCard))).colorScheme.error;
        final badge = find.text(l10n(surface.locale).wfEscalatedBadge);
        expect(badge, findsOneWidget);
        expect(tester.widget<Text>(badge).style?.color, error);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.priority_high_rounded)).color,
          error,
        );
      });
    }

    testWidgets('other facts use the muted tone', (tester) async {
      await pumpSurface(
        tester,
        surfaces[3],
        _card(Visit(id: 1, scheduledDatetime: _schedule, isEscalated: false)),
      );
      final muted = Theme.of(tester.element(find.byType(VisitCard)))
          .colorScheme
          .onSurfaceVariant;
      expect(find.byIcon(Icons.priority_high_rounded), findsNothing);
      expect(tester.widget<Icon>(find.byIcon(Icons.schedule)).color, muted);
      expect(
        tester.widget<Text>(_metaText(Icons.schedule)).style?.color,
        muted,
      );
    });
  });

  group('VisitCard schedule', () {
    testWidgets('English: month name, Latin digits', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _card(Visit(id: 1, scheduledDatetime: _schedule)),
      );
      expect(find.text('Jul 15, 14:30'), findsOneWidget);
    });

    testWidgets('Arabic: Arabic month name, still Latin digits',
        (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        _card(Visit(id: 1, scheduledDatetime: _schedule)),
      );
      final text = tester.widget<Text>(_metaText(Icons.schedule)).data!;
      expect(text, _expectedSchedule(tester, _schedule));
      expect(text, contains('يوليو'));
      expect(text, contains('14:30'));
      expect(text, contains('15'));
      expect(RegExp('[٠-٩]').hasMatch(text), isFalse);
    });

    testWidgets('no schedule, no schedule line', (tester) async {
      await pumpSurface(tester, phoneEn, _card(const Visit(id: 1)));
      expect(find.byIcon(Icons.schedule), findsNothing);
    });

    for (final (surface, tzName) in [
      (phoneEn, 'Asia/Riyadh'),
      (phoneAr, 'Asia/Riyadh'),
      (phoneEn, 'Africa/Cairo'),
    ]) {
      testWidgets('shown in the signed-in user\'s zone ($tzName) — $surface',
          (tester) async {
        // 11:30 UTC is 14:30 in Riyadh (UTC+3) and in Cairo on summer time.
        final utc = DateTime.utc(2026, 7, 15, 11, 30);
        await pumpSurface(
          tester,
          surface,
          BlocProvider<AuthBloc>(
            create: (_) => _SignedIn(tzName),
            child: _card(Visit(id: 1, scheduledDatetime: utc)),
          ),
        );
        final text = tester.widget<Text>(_metaText(Icons.schedule)).data!;
        expect(text, contains('14:30'));
        expect(text, _expectedSchedule(tester, DateTime(2026, 7, 15, 14, 30)));
        if (surface.isArabic) expect(text, contains('يوليو'));
      });
    }

    testWidgets('an unknown zone name falls back to the device clock',
        (tester) async {
      final utc = DateTime.utc(2026, 7, 15, 11, 30);
      await pumpSurface(
        tester,
        phoneEn,
        BlocProvider<AuthBloc>(
          create: (_) => _SignedIn('Mars/Olympus_Mons'),
          child: _card(Visit(id: 1, scheduledDatetime: utc)),
        ),
      );
      expectCleanLayout(tester);
      expect(
        tester.widget<Text>(_metaText(Icons.schedule)).data,
        _expectedSchedule(tester, utc.toLocal()),
      );
    });
  });

  group('VisitCard tap', () {
    testWidgets('onTap fires once per tap, anywhere on the card',
        (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        _card(_full(phoneEn), onTap: () => taps++, showEmployee: true),
      );
      await tester.tap(find.byType(VisitCard));
      await tester.pump();
      expect(taps, 1);
      await tester.tap(find.byType(VisitStateBadge));
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('without onTap the card is inert', (tester) async {
      await pumpSurface(tester, phoneEn, _card(const Visit(id: 1)));
      expect(
        tester.widget<InkWell>(find.descendant(
          of: find.byType(VisitCard),
          matching: find.byType(InkWell),
        )).onTap,
        isNull,
      );
      await tester.tap(find.byType(VisitCard));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tappable card is announced as tappable', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(
        tester,
        phoneEn,
        _card(const Visit(id: 5, partnerName: 'Acme'), onTap: () {}),
      );
      expect(
        tester.getSemantics(find.text('Acme')),
        containsSemantics(hasTapAction: true),
      );
      handle.dispose();
    });
  });
}
