import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/location/location_describe.dart';
import 'package:location_gps/core/utils/app_date.dart';
import 'package:location_gps/core/utils/duration_format.dart';
import 'package:location_gps/features/auth/bloc/auth_bloc.dart';
import 'package:location_gps/features/auth/data/models/user.dart';
import 'package:location_gps/features/visits/bloc/visit_detail_cubit.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_participant.dart';
import 'package:location_gps/features/visits/view/visit_detail_row.dart';
import 'package:location_gps/features/visits/view/visit_detail_sections.dart';
import 'package:location_gps/features/visits/view/visit_labels.dart';
import 'package:location_gps/features/visits/view/visit_section.dart';
import 'package:location_gps/shared/widgets/widgets.dart';
import 'package:location_gps/shared/extensions/context_extensions.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

final _at = fixtureDay;

/// Every optional field of every section, with Odoo-shaped long values.
Visit _full({
  VisitState state = VisitState.submitted,
  List<VisitParticipant>? participants,
}) =>
    Visit(
      id: 42,
      name: 'VIS/2026/00042',
      visitType: VisitType.project,
      projectName: 'مشروع تطوير الواجهة البحرية — المرحلة الثانية',
      partnerId: 7,
      partnerName: LongText.arabicCompany,
      employeeName: LongText.arabicPerson,
      directManagerName: LongText.arabicPerson,
      higherManagerName: 'منى عادل عبد الرحمن الشمري',
      scheduledDatetime: _at,
      purpose: '${LongText.english} ${LongText.arabicCompany}',
      location: 'طريق الملك عبد العزيز، حي الملقا، الرياض ١٢٤٧٣، السعودية',
      outcome: 'تم الاتفاق على تسليم الدفعة الأولى خلال أسبوعين',
      startDatetime: _at,
      endDatetime: _at.add(const Duration(hours: 1, minutes: 5)),
      startLat: 24.7136,
      startLng: 46.6753,
      endLat: 24.7140,
      endLng: 46.6760,
      startLocation: 'حي الملقا، الرياض',
      endLocation: null,
      submittedDate: _at,
      approvedDate: _at,
      approvedByName: LongText.arabicPerson,
      rejectedDate: _at,
      rejectedByName: 'Sam Sales',
      rejectReason: 'The customer asked to move the meeting to next week.',
      isEscalated: true,
      escalationDate: _at,
      state: state,
      participants: participants ??
          const [
            VisitParticipant(
              id: 1,
              employeeName: LongText.arabicPerson,
              employeeId: 31,
              managerId: 20,
              approvalState: ParticipantApprovalState.pending,
            ),
            VisitParticipant(
              id: 2,
              employeeName: 'Sam Sales',
              employeeId: 32,
              approvalState: ParticipantApprovalState.approved,
            ),
            VisitParticipant(
              id: 3,
              employeeId: 33,
              approvalState: ParticipantApprovalState.rejected,
            ),
            VisitParticipant(id: 4, employeeName: 'Lina'),
          ],
    );

const _empty = Visit(id: 9);

String _df(WidgetTester tester, DateTime at, {bool weekday = true}) {
  final context = tester.element(find.byType(Scaffold).first);
  return (weekday
          ? AppDate.weekdayDateTimeFormat(context)
          : AppDate.dateTimeFormat(context))
      .format(at.toLocal());
}

/// The rows of the section titled [title], as (label, value) pairs.
List<(String, String)> _rows(WidgetTester tester, String title) {
  final section = find.ancestor(
    of: find.text(title),
    matching: find.byType(VisitSection),
  );
  return [
    for (final row in tester.widgetList<VisitDetailRow>(
        find.descendant(of: section, matching: find.byType(VisitDetailRow))))
      (row.label, row.value),
  ];
}

VisitDetailRow _row(WidgetTester tester, String label) =>
    tester.widget<VisitDetailRow>(find.byWidgetPredicate(
        (w) => w is VisitDetailRow && w.label == label));

void main() {
  setUpAll(initHarness);

  late FakeVisitsRepo repo;
  late VisitDetailCubit cubit;
  late StubAuthBloc auth;

  setUp(() {
    repo = FakeVisitsRepo(visit: _full());
    cubit = VisitDetailCubit(repository: repo, visitId: 42);
    auth = StubAuthBloc(manager);
  });

  tearDown(() async {
    await cubit.close();
    await auth.close();
  });

  Widget withDetailBlocs(Widget child, {AuthBloc? as}) => withBlocs(
        auth: as ?? auth,
        extra: [BlocProvider<VisitDetailCubit>.value(value: cubit)],
        child,
      );

  Widget allSections(Visit visit) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VisitInfoSection(visit: visit),
            VisitApprovalSection(visit: visit),
            const VisitMockLocationBanner(),
            VisitExecutionSection(visit: visit),
            VisitParticipantsSection(visit: visit),
            VisitHistorySection(visit: visit),
          ],
        ),
      );

  group('layout', () {
    testOnEverySurface(
      'all six sections, fully populated',
      (s) => withDetailBlocs(allSections(_full())),
      scrollable: true,
      verify: (tester, s) async {
        final t = l10n(s.locale);
        for (final title in [
          t.wfSectionVisitInfo,
          t.wfSectionApproval,
          t.wfSectionExecution,
          t.wfParticipantsSection,
          t.wfApprovalHistory,
        ]) {
          expect(find.text(title), findsOneWidget, reason: title);
        }
        expect(find.text(t.wfMockFlagBannerTitle), findsOneWidget);
      },
    );

    testOnEverySurface(
      'an empty visit renders only the banner and the participants shell',
      (s) => withDetailBlocs(allSections(_empty)),
      scrollable: true,
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.text(t.wfSectionVisitInfo), findsNothing);
        expect(find.text(t.wfSectionApproval), findsNothing);
        expect(find.text(t.wfSectionExecution), findsNothing);
        expect(find.text(t.wfApprovalHistory), findsNothing);
        expect(find.byType(VisitDetailRow), findsNothing);
      },
    );
  });

  group('VisitInfoSection', () {
    testWidgets('lists customer, project, schedule, purpose and location',
        (tester) async {
      await pumpSurface(tester, phoneEn, VisitInfoSection(visit: _full()),
          scrollable: true);
      final t = l10n(english);
      expect(_rows(tester, t.wfSectionVisitInfo), [
        (t.wfFieldCustomer, LongText.arabicCompany),
        (t.wfFieldProject, 'مشروع تطوير الواجهة البحرية — المرحلة الثانية'),
        (t.wfFieldSchedule, _df(tester, _at)),
        (t.wfFieldPurpose, '${LongText.english} ${LongText.arabicCompany}'),
        (
          t.wfFieldLocation,
          'طريق الملك عبد العزيز، حي الملقا، الرياض ١٢٤٧٣، السعودية'
        ),
      ]);
    });

    testWidgets('an opportunity is labelled and badged as one',
        (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        const VisitInfoSection(
          visit: Visit(
            id: 1,
            visitType: VisitType.opportunity,
            opportunityName: 'برج ب',
          ),
        ),
      );
      final row = _row(tester, l10n(arabic).wfFieldOpportunity);
      expect(row.value, 'برج ب');
      expect(row.icon, Icons.emoji_events_outlined);
    });

    testWidgets('only a known customer opens the customer profile',
        (tester) async {
      final log = await pumpRouted(
        tester,
        phoneEn,
        SingleChildScrollView(child: VisitInfoSection(visit: _full())),
      );
      final customer = _row(tester, l10n(english).wfFieldCustomer);
      expect(customer.onTap, isNotNull);
      await tester.tap(find.text(LongText.arabicCompany));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(log.locations, ['/customers/7']);

      await pumpSurface(
        tester,
        phoneEn,
        const VisitInfoSection(visit: Visit(id: 1, partnerName: 'Walk-in')),
      );
      expect(_row(tester, l10n(english).wfFieldCustomer).onTap, isNull);
    });

    testWidgets('nothing to show: no section at all', (tester) async {
      await pumpSurface(tester, phoneEn, const VisitInfoSection(visit: _empty));
      expect(find.byType(VisitSection), findsNothing);
    });
  });

  group('VisitApprovalSection', () {
    testWidgets('lists the responsible and both managers', (tester) async {
      await pumpSurface(tester, phoneAr, VisitApprovalSection(visit: _full()));
      final t = l10n(arabic);
      expect(_rows(tester, t.wfSectionApproval), [
        (t.wfFieldResponsible, LongText.arabicPerson),
        (t.wfFieldDirectManager, LongText.arabicPerson),
        (t.wfFieldHigherManager, 'منى عادل عبد الرحمن الشمري'),
      ]);
    });

    testWidgets('a partial chain lists what it has', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const VisitApprovalSection(
            visit: Visit(id: 1, higherManagerName: 'Mona')),
      );
      expect(_rows(tester, l10n(english).wfSectionApproval),
          [(l10n(english).wfFieldHigherManager, 'Mona')]);
    });

    testWidgets('nothing to show: no section at all', (tester) async {
      await pumpSurface(
          tester, phoneEn, const VisitApprovalSection(visit: _empty));
      expect(find.byType(VisitSection), findsNothing);
    });
  });

  group('VisitMockLocationBanner', () {
    testWidgets('warns in the error tones, localized', (tester) async {
      await pumpSurface(tester, phoneAr, const VisitMockLocationBanner());
      final t = l10n(arabic);
      final cs = Theme.of(tester.element(find.byType(VisitMockLocationBanner)))
          .colorScheme;
      expect(find.text(t.wfMockFlagBannerTitle), findsOneWidget);
      expect(find.text(t.wfMockFlagBannerBody), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.gpp_bad_outlined)).color,
          cs.error);
      final box = tester.widget<Container>(find
          .descendant(
              of: find.byType(VisitMockLocationBanner),
              matching: find.byType(Container))
          .first);
      expect((box.decoration! as BoxDecoration).color, cs.errorContainer);
      expect(
          tester.widget<Text>(find.text(t.wfMockFlagBannerBody)).style?.color,
          cs.onErrorContainer);
    });
  });

  group('VisitExecutionSection', () {
    testWidgets('start, end, places, duration and outcome', (tester) async {
      await pumpSurface(tester, phoneEn, VisitExecutionSection(visit: _full()),
          scrollable: true);
      final t = l10n(english);
      expect(_rows(tester, t.wfSectionExecution), [
        (t.wfStartedLabel, _df(tester, _at)),
        (t.wfFieldStartLocation, 'حي الملقا، الرياض'),
        (t.wfEndedLabel, _df(tester, _at.add(const Duration(hours: 1, minutes: 5)))),
        // No place name recorded at the end: the coordinates stand in.
        (
          t.wfFieldEndLocation,
          LocationDescriber.formatCoordinates(24.7140, 46.6760)
        ),
        (
          t.wfDurationLabel,
          const Duration(hours: 1, minutes: 5)
              .localized(tester.element(find.byType(VisitExecutionSection)))
        ),
        (t.wfFieldOutcome, 'تم الاتفاق على تسليم الدفعة الأولى خلال أسبوعين'),
      ]);
      // Each GPS point opens in maps.
      final pills =
          tester.widgetList<VisitMapsPill>(find.byType(VisitMapsPill)).toList();
      expect(pills, hasLength(2));
      expect((pills[0].latitude, pills[0].longitude, pills[0].label),
          (24.7136, 46.6753, 'حي الملقا، الرياض'));
      expect((pills[1].latitude, pills[1].longitude, pills[1].label),
          (24.7140, 46.6760, null));
      // Start green, end amber.
      final context = tester.element(find.byType(VisitExecutionSection));
      expect(_row(tester, t.wfStartedLabel).iconColor, context.visitSuccess);
      expect(_row(tester, t.wfEndedLabel).iconColor, context.visitWarning);
      expect(find.text(t.wfShortVisitHint), findsNothing);
    });

    testWidgets('a place without coordinates has no maps button',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const VisitExecutionSection(
            visit: Visit(id: 1, startLocation: 'Olaya St')),
      );
      final row = _row(tester, l10n(english).wfFieldStartLocation);
      expect(row.value, 'Olaya St');
      expect(row.trailing, isNull);
      expect(find.byType(VisitMapsPill), findsNothing);
    });

    testWidgets('half a coordinate is no coordinate', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const VisitExecutionSection(visit: Visit(id: 1, startLat: 24.7)),
      );
      expect(find.byType(VisitSection), findsNothing);
    });

    testWidgets('a visit shorter than the minimum is flagged', (tester) async {
      await pumpSurface(
        tester,
        surfaces[0],
        VisitExecutionSection(
          visit: Visit(
            id: 1,
            startDatetime: _at,
            endDatetime: _at.add(const Duration(seconds: 70)),
          ),
        ),
      );
      final t = l10n(arabic);
      final context = tester.element(find.byType(VisitExecutionSection));
      final row = _row(tester, t.wfDurationLabel);
      expect(row.valueColor, context.visitWarning);
      expect(row.iconColor, context.visitWarning);
      final pill = tester.widget<TonePill>(find.byType(TonePill));
      expect(pill.label, t.wfShortVisitHint);
      expect(pill.color, context.visitWarning);
      expectCleanLayout(tester);
    });

    testWidgets('an end before the start shows no duration', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        VisitExecutionSection(
          visit: Visit(
            id: 1,
            startDatetime: _at,
            endDatetime: _at.subtract(const Duration(minutes: 5)),
          ),
        ),
      );
      expect(find.text(l10n(english).wfDurationLabel), findsNothing);
      expect(find.text(l10n(english).wfStartedLabel), findsOneWidget);
    });

    testWidgets('nothing to show: no section at all', (tester) async {
      await pumpSurface(
          tester, phoneEn, const VisitExecutionSection(visit: _empty));
      expect(find.byType(VisitSection), findsNothing);
    });
  });

  group('VisitParticipantsSection', () {
    Future<void> pumpParticipants(
      WidgetTester tester, {
      Visit? visit,
      AuthUser? user = manager,
      Surface surface = phoneEn,
    }) async {
      // Not closed: a bloc created inside the fake-async test body never
      // finishes closing outside it. It holds no timers or subscriptions.
      final as = StubAuthBloc(user);
      await pumpSurface(
        tester,
        surface,
        withDetailBlocs(
          VisitParticipantsSection(visit: visit ?? _full()),
          as: as,
        ),
        scrollable: true,
      );
    }

    Finder approve(Surface s) =>
        find.byTooltip(l10n(s.locale).wfApproveParticipant);
    Finder reject(Surface s) =>
        find.byTooltip(l10n(s.locale).wfRejectParticipant);

    testWidgets('each attendee: name (or a stand-in) and a toned state',
        (tester) async {
      await pumpParticipants(tester);
      final t = l10n(english);
      expect(find.text(LongText.arabicPerson), findsOneWidget);
      expect(find.text('Sam Sales'), findsOneWidget);
      expect(find.text(t.wfUnknownEmployee), findsOneWidget);
      expect(find.text(t.wfParticipantPending), findsOneWidget);
      expect(find.text(t.wfParticipantApprovedState), findsOneWidget);
      expect(find.text(t.wfParticipantRejectedState), findsOneWidget);
      expect(find.text(t.wfStateUnknown), findsOneWidget);
      final context = tester.element(find.byType(VisitParticipantsSection));
      expect(
        tester.widget<Text>(find.text(t.wfParticipantApprovedState)).style?.color,
        context.visitSuccess,
      );
      final name = tester.widget<Text>(find.text(LongText.arabicPerson));
      expect(name.maxLines, 2);
    });

    testWidgets('the attendee\'s manager decides on a pending line only',
        (tester) async {
      await pumpParticipants(tester);
      expect(approve(phoneEn), findsOneWidget);
      expect(reject(phoneEn), findsOneWidget);
    });

    testWidgets('the decision buttons are full tap targets', (tester) async {
      await pumpParticipants(tester, surface: surfaces[0]);
      for (final tooltip in [approve(surfaces[0]), reject(surfaces[0])]) {
        // The tooltip wraps only the 40dp visual; the padded hit area is the
        // IconButton's own box.
        final button =
            find.ancestor(of: tooltip, matching: find.byType(IconButton));
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
        expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      }
      expectCleanLayout(tester);
    });

    testWidgets('approve reaches the server once', (tester) async {
      await pumpParticipants(tester);
      await tester.tap(approve(phoneEn));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.calls, ['approveParticipant:1']);
    });

    testWidgets('reject asks for a reason first', (tester) async {
      await pumpParticipants(tester, surface: phoneAr);
      await tester.tap(reject(phoneAr));
      await tester.pumpAndSettle();
      final t = l10n(arabic);
      expect(find.text(t.wfRejectReason), findsOneWidget);

      // Dismissing the sheet sends nothing.
      await tester.tap(find.byTooltip(t.commonClose));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);

      await tester.tap(reject(phoneAr));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  تعارض في المواعيد  ');
      await tester.tap(find.widgetWithText(FilledButton, t.wfActionReject));
      await tester.pumpAndSettle();
      expect(repo.calls, ['rejectParticipant:1|تعارض في المواعيد']);
    });

    for (final (why, visit, user) in [
      ('a visit past approval', _full(state: VisitState.approved), manager),
      ('nobody signed in', _full(), null),
      (
        'nobody decides on their own line',
        _full(),
        const AuthUser(uid: 9, username: 'p', employeeId: 31,
            visitRole: VisitRole.manager),
      ),
      ('a plain user who is not the manager', _full(), stranger),
    ]) {
      testWidgets('no decision buttons: $why', (tester) async {
        await pumpParticipants(tester, visit: visit, user: user);
        expect(approve(phoneEn), findsNothing);
        expect(reject(phoneEn), findsNothing);
      });
    }

    testWidgets('the legacy waiting state and a visits admin can decide',
        (tester) async {
      await pumpParticipants(
        tester,
        visit: _full(state: VisitState.waitingParticipantManagerApproval),
        user: const AuthUser(uid: 8, username: 'a', employeeId: 77,
            isAdmin: true),
      );
      expect(approve(phoneEn), findsOneWidget);
    });

    testWidgets('the direct manager decides even without the manager role',
        (tester) async {
      await pumpParticipants(
        tester,
        user: const AuthUser(uid: 5, username: 'm', employeeId: 20),
      );
      expect(approve(phoneEn), findsOneWidget);
    });

    testWidgets('no attendees: the section shell is still drawn',
        (tester) async {
      await pumpParticipants(tester, visit: _full(participants: const []));
      expect(find.text(l10n(english).wfParticipantsSection), findsOneWidget);
      expectCleanLayout(tester);
    });
  });

  group('VisitHistorySection', () {
    testWidgets('submitted, escalated, approved, rejected and the reason',
        (tester) async {
      await pumpSurface(tester, phoneEn, VisitHistorySection(visit: _full()),
          scrollable: true);
      final t = l10n(english);
      final at = _df(tester, _at, weekday: false);
      final sep = t.commonListSeparator;
      expect(_rows(tester, t.wfApprovalHistory), [
        (t.wfSubmittedOn, at),
        (t.wfEscalatedBadge, at),
        // An Arabic name on an English screen is isolated.
        (
          t.wfApprovedByOn,
          '${bidiIsolateIfForeign(LongText.arabicPerson, rtl: false)}$sep$at',
        ),
        (t.wfRejectedByOn, 'Sam Sales$sep$at'),
        (t.wfReason, 'The customer asked to move the meeting to next week.'),
      ]);
      final cs = Theme.of(tester.element(find.byType(VisitHistorySection)))
          .colorScheme;
      expect(_row(tester, t.wfEscalatedBadge).iconColor, cs.error);
      expect(_row(tester, t.wfReason).iconColor, cs.error);
    });

    testWidgets('a decision without a date names only the person',
        (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        const VisitHistorySection(
            visit: Visit(id: 1, approvedByName: 'منى')),
      );
      expect(_row(tester, l10n(arabic).wfApprovedByOn).value, 'منى');
    });

    testWidgets('an escalation date alone is not an escalation',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        VisitHistorySection(visit: Visit(id: 1, escalationDate: _at)),
      );
      expect(find.byType(VisitSection), findsNothing);
    });

    testWidgets('an escalated flag alone has no date to show',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const VisitHistorySection(visit: Visit(id: 1, isEscalated: true)),
      );
      expect(find.byType(VisitSection), findsNothing);
    });
  });
}
