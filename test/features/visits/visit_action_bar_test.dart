import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/core/di/service_locator.dart';
import 'package:location_gps/core/location/location_describe.dart';
import 'package:location_gps/core/location/location_outcome.dart';
import 'package:location_gps/core/location/location_service.dart';
import 'package:location_gps/features/auth/data/models/user.dart';
import 'package:location_gps/features/visits/bloc/visit_detail_cubit.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_participant.dart';
import 'package:location_gps/features/visits/data/visit_tracking_consent.dart';
import 'package:location_gps/features/visits/view/visit_action_bar.dart';
import 'package:location_gps/features/visits/view/visit_tracking_disclosure_dialog.dart';
import 'package:location_gps/features/visits/visit_constants.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';
import 'package:location_gps/shared/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

/// The bar's buttons, by the label each shows.
enum _B { submit, approve, reject, start, end, reschedule, photo, file, cancel }

String _label(AppLocalizations t, _B b) => switch (b) {
      _B.submit => t.wfActionSubmit,
      _B.approve => t.wfActionApprove,
      _B.reject => t.wfActionReject,
      _B.start => t.wfActionStart,
      _B.end => t.wfActionEnd,
      _B.reschedule => t.wfActionReschedule,
      _B.photo => t.wfActionTakePhoto,
      _B.file => t.wfActionAddAttachment,
      _B.cancel => t.wfActionCancel,
    };

const _files = [_B.photo, _B.file];
/// What the visit's own employee sees — spelled out per state, not derived
/// from the model's getters, so a regression in either shows up here.
const Map<VisitState, List<_B>> _ownerSees = {
  VisitState.draft: [_B.submit, ..._files, _B.cancel],
  VisitState.submitted: [_B.reschedule, ..._files, _B.cancel],
  VisitState.waitingParticipantManagerApproval: [
    _B.reschedule, ..._files, _B.cancel,
  ],
  VisitState.waitingDirectManagerApproval: [
    _B.reschedule, ..._files, _B.cancel,
  ],
  VisitState.escalated: [_B.reschedule, ..._files, _B.cancel],
  VisitState.approved: [_B.start, _B.reschedule, ..._files, _B.cancel],
  VisitState.rejected: [_B.submit],
  VisitState.cancelled: [],
  VisitState.rescheduleRequested: [
    _B.submit, _B.reschedule, ..._files, _B.cancel,
  ],
  VisitState.inProgress: [_B.end, ..._files],
  VisitState.done: [],
  VisitState.unknown: [..._files],
};

/// What an approver who is not the owner sees.
const Map<VisitState, List<_B>> _approverSees = {
  VisitState.draft: [..._files, _B.cancel],
  VisitState.submitted: [_B.approve, _B.reject, ..._files, _B.cancel],
  VisitState.waitingParticipantManagerApproval: [
    _B.approve, _B.reject, ..._files, _B.cancel,
  ],
  VisitState.waitingDirectManagerApproval: [
    _B.approve, _B.reject, ..._files, _B.cancel,
  ],
  VisitState.escalated: [_B.approve, _B.reject, ..._files, _B.cancel],
  VisitState.approved: [..._files, _B.cancel],
  VisitState.rejected: [],
  VisitState.cancelled: [],
  VisitState.rescheduleRequested: [
    _B.approve, _B.reject, ..._files, _B.cancel,
  ],
  VisitState.inProgress: [..._files],
  VisitState.done: [],
  VisitState.unknown: [..._files],
};

Visit _visit(
  VisitState state, {
  int attachments = 0,
  List<VisitParticipant> participants = const [],
  ApprovalTrack attendees = ApprovalTrack.unknown,
  String? outcome,
}) =>
    Visit(
      id: 42,
      employeeId: ownerEmployeeId,
      state: state,
      attachmentCount: attachments,
      participants: participants,
      attendeeApprovalState: attendees,
      outcome: outcome,
      scheduledDatetime: DateTime.now().add(const Duration(days: 2)),
      purpose: 'Contract review',
      location: 'Olaya St',
    );

const _imagePicker = MethodChannel('plugins.flutter.io/image_picker');
const _filePicker = MethodChannel('miguelruivo.flutter.plugins.filepicker');
const _permissions =
    MethodChannel('flutter.baseflow.com/permissions/methods');

/// Answers [channel] with [handler] for this test, recording every call.
List<MethodCall> _mock(
  MethodChannel channel,
  Future<Object?> Function(MethodCall call) handler,
) {
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) {
    calls.add(call);
    return handler(call);
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return calls;
}

void main() {
  setUpAll(initHarness);

  late FakeVisitsRepo repo;
  late FakeLocationService location;
  late FakeDescriber describer;

  setUp(() {
    repo = FakeVisitsRepo();
    location = FakeLocationService();
    describer = FakeDescriber();
    sl.registerSingleton<LocationService>(location);
    sl.registerSingleton<LocationDescriber>(describer);
  });

  tearDown(() => sl.reset());

  /// The bar at the bottom of a page, over a real [VisitDetailCubit] backed by
  /// the recording repository. The blocs are created (and owned) by the tree:
  /// one made inside a fake-async test cannot be closed from outside it.
  Widget host(Visit visit, AuthUser? user) {
    repo.visit = visit;
    return withBlocs(
      auth: StubAuthBloc(user),
      extra: [
        BlocProvider<VisitDetailCubit>(
          create: (_) => VisitDetailCubit(repository: repo, visitId: visit.id),
        ),
      ],
      Column(
        children: [
          const Expanded(child: SizedBox.expand()),
          VisitActionBar(visit: visit),
        ],
      ),
    );
  }

  Future<void> pumpBar(
    WidgetTester tester,
    Visit visit, {
    AuthUser? user = fieldRep,
    Surface surface = phoneEn,
  }) =>
      pumpSurface(tester, surface, host(visit, user));

  List<String> labels(WidgetTester tester) =>
      [for (final a in _actions(tester)) a.label];

  /// By the label the action carries, not the text it shows: a spinning
  /// button hides its label.
  Finder button(Surface s, _B b) {
    final label = _label(l10n(s.locale), b);
    return find.byWidgetPredicate((w) => _Action.of(w)?.label == label);
  }

  /// Fixed frames instead of `pumpAndSettle`: while a sheet or dialog is open
  /// the button that opened it spins, and a spinner never settles.
  Future<void> settle(WidgetTester tester) =>
      pumpFrames(tester, const Duration(seconds: 1));

  Future<void> tapButton(WidgetTester tester, _B b, {Surface s = phoneEn}) async {
    await tester.ensureVisible(button(s, b));
    await tester.tap(button(s, b));
    await tester.pump();
  }

  // ─── Which buttons ───────────────────────────────────────────────────────

  group('which buttons show', () {
    for (final (role, user, table) in [
      ('owner', fieldRep, _ownerSees),
      ('approver', manager, _approverSees),
      // A manager who owns the visit never decides on it.
      ('manager who owns it', managerOwner, _ownerSees),
    ]) {
      for (final state in VisitState.values) {
        testWidgets('$role × ${state.name}', (tester) async {
          await pumpBar(tester, _visit(state), user: user);
          final t = l10n(english);
          final expected = [for (final b in table[state]!) _label(t, b)];
          expect(labels(tester), expected);
          if (expected.isEmpty) {
            expect(find.byType(VisitActionBar), findsOneWidget);
            expect(tester.getSize(find.byType(VisitActionBar)).height, 0);
          }
          for (final b in _actions(tester)) {
            expect(b.onPressed, isNotNull, reason: b.label);
            expect(b.loading, isFalse);
          }
        });
      }
    }

    for (final state in VisitState.values) {
      testWidgets('a stranger sees nothing × ${state.name}', (tester) async {
        await pumpBar(tester, _visit(state), user: stranger);
        expect(_actions(tester), isEmpty);
        expect(tester.getSize(find.byType(VisitActionBar)).height, 0);
      });
    }

    testWidgets('signed out, or a profile without an employee: nothing',
        (tester) async {
      await pumpBar(tester, _visit(VisitState.approved), user: null);
      expect(_actions(tester), isEmpty);
      await pumpBar(
        tester,
        _visit(VisitState.approved),
        user: const AuthUser(uid: 1, username: 'x', profileIncomplete: true),
      );
      expect(_actions(tester), isEmpty);
    });

    testWidgets('an Odoo admin without a visit role still approves',
        (tester) async {
      await pumpBar(
        tester,
        _visit(VisitState.submitted),
        user: const AuthUser(uid: 7, username: 'admin', employeeId: 1,
            isAdmin: true),
      );
      expect(labels(tester), contains(l10n(english).wfActionApprove));
    });

    for (final (why, visit) in [
      (
        'an attendee line is pending',
        _visit(VisitState.submitted, participants: const [
          VisitParticipant(
              id: 1, approvalState: ParticipantApprovalState.pending),
        ]),
      ),
      (
        'the attendee track is pending',
        _visit(VisitState.submitted, attendees: ApprovalTrack.pending),
      ),
    ]) {
      testWidgets('approve waits while $why; reject stays', (tester) async {
        await pumpBar(tester, visit, user: manager, surface: phoneAr);
        final t = l10n(arabic);
        expect(labels(tester), [
          t.wfActionReject,
          t.wfActionTakePhoto,
          t.wfActionAddAttachment,
          t.wfActionCancel,
        ]);
        final note = tester.widget<Text>(find.text(t.wfApproveWaitsForAttendees));
        final context = tester.element(find.byType(VisitActionBar));
        expect(note.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
      });
    }

    testWidgets('decided attendees do not hold approval', (tester) async {
      await pumpBar(
        tester,
        _visit(VisitState.submitted, participants: const [
          VisitParticipant(
              id: 1, approvalState: ParticipantApprovalState.approved),
          VisitParticipant(
              id: 2, approvalState: ParticipantApprovalState.rejected),
        ]),
        user: manager,
      );
      expect(labels(tester).first, l10n(english).wfActionApprove);
    });

    testWidgets('the attachment button counts what is attached',
        (tester) async {
      await pumpBar(tester, _visit(VisitState.inProgress, attachments: 3),
          surface: phoneAr);
      final t = l10n(arabic);
      expect(labels(tester), contains(t.wfActionAddAttachmentCount(3)));
      expect(labels(tester), isNot(contains(t.wfActionAddAttachment)));
    });

    testWidgets('each action wears its variant and glyph', (tester) async {
      await pumpBar(tester, _visit(VisitState.submitted), user: manager);
      final t = l10n(english);
      _Action b(String label) =>
          _actions(tester).firstWhere((a) => a.label == label);
      expect(b(t.wfActionApprove).kind, _Kind.primary);
      expect(b(t.wfActionApprove).icon, Icons.check_circle_outline);
      expect(b(t.wfActionReject).kind, _Kind.destructive);
      expect(b(t.wfActionTakePhoto).kind, _Kind.tool);
      expect(b(t.wfActionTakePhoto).icon, Icons.photo_camera_outlined);
      expect(b(t.wfActionAddAttachment).icon, Icons.attach_file);
      expect(b(t.wfActionCancel).kind, _Kind.destructiveTool);
      expect(b(t.wfActionCancel).icon, Icons.block);

      await pumpBar(tester, _visit(VisitState.approved));
      expect(b(t.wfActionStart).kind, _Kind.primary);
      expect(b(t.wfActionStart).icon, Icons.play_arrow_rounded);
      expect(b(t.wfActionReschedule).kind, _Kind.tool);
    });
  });

  // ─── Layout ──────────────────────────────────────────────────────────────

  group('layout', () {
    testOnEverySurface(
      'an approver on a pending visit with attachments',
      (s) => host(
        _visit(VisitState.submitted,
            attachments: 12, attendees: ApprovalTrack.pending),
        manager,
      ),
      verify: (tester, s) async {
        expect(_actions(tester), hasLength(4));
        expect(find.text(l10n(s.locale).wfApproveWaitsForAttendees),
            findsOneWidget);
      },
    );

    testOnEverySurface(
      'the owner with five actions: capped and scrollable',
      (s) => host(_visit(VisitState.rescheduleRequested), fieldRep),
      verify: (tester, s) async {
        final bar = tester.getSize(find.byType(VisitActionBar));
        expect(bar.height,
            lessThanOrEqualTo(s.size.height * VisitConstants.actionBarMaxHeightFraction + 1));
        // Every button is reachable.
        for (final b in [_B.submit, _B.reschedule, _B.photo, _B.file, _B.cancel]) {
          await tester.ensureVisible(button(s, b));
          await tester.pump();
          final rect = tester.getRect(button(s, b));
          expect(rect.bottom, lessThanOrEqualTo(s.size.height + 0.5));
          expect(rect.height, greaterThanOrEqualTo(kMinInteractiveDimension));
        }
      },
    );

    testWidgets('a portrait phone: the decision full width, tools in a row',
        (tester) async {
      await pumpBar(tester, _visit(VisitState.approved));
      final start = tester.getRect(button(phoneEn, _B.start));
      expect(start.width, greaterThan(phoneEn.size.width * 0.8));
      final tools = [
        for (final b in [_B.reschedule, _B.photo, _B.file, _B.cancel])
          tester.getRect(button(phoneEn, b)),
      ];
      for (final r in tools) {
        expect(r.top, moreOrLessEquals(tools.first.top));
        expect(r.top, greaterThan(start.bottom));
        expect(r.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      }
      for (var i = 1; i < tools.length; i++) {
        expect(tools[i].left, greaterThan(tools[i - 1].left),
            reason: 'left to right in English');
      }
      // One row of tools under one button: far less than the old five
      // stacked buttons.
      expect(tester.getSize(find.byType(VisitActionBar)).height,
          lessThan(phoneEn.size.height * 0.3));
    });

    testWidgets('every tool names itself for touch and screen readers',
        (tester) async {
      await pumpBar(tester, _visit(VisitState.approved), surface: phoneAr);
      final t = l10n(arabic);
      for (final label in [
        t.wfActionReschedule,
        t.wfActionTakePhoto,
        t.wfActionAddAttachment,
        t.wfActionCancel,
      ]) {
        expect(find.byTooltip(label), findsOneWidget);
      }
    });

    for (final s in [surfaces[2], surfaces[3]]) {
      testWidgets('one row on ${s.name}', (tester) async {
        await pumpBar(tester, _visit(VisitState.approved), surface: s);
        final first = tester.getRect(button(s, _B.start));
        final second = tester.getRect(button(s, _B.reschedule));
        expect(second.center.dy, moreOrLessEquals(first.center.dy, epsilon: 1));
        expect(first.width, lessThan(s.size.width * 0.7));
        expect((first.center.dx < second.center.dx), !s.isArabic,
            reason: 'the row follows the reading direction');
      });
    }

    testWidgets('the bar is the surface colour with a hairline on top',
        (tester) async {
      await pumpBar(tester, _visit(VisitState.approved));
      final context = tester.element(find.byType(VisitActionBar));
      final box = tester.widget<Container>(find
          .descendant(
              of: find.byType(VisitActionBar), matching: find.byType(Container))
          .first);
      final decoration = box.decoration! as BoxDecoration;
      final cs = Theme.of(context).colorScheme;
      expect(decoration.color, cs.surface);
      expect((decoration.border! as Border).top.color, cs.outlineVariant);
    });
  });

  // ─── Actions ─────────────────────────────────────────────────────────────

  group('simple actions', () {
    testWidgets('submit reaches the server once', (tester) async {
      await pumpBar(tester, _visit(VisitState.draft));
      await tapButton(tester, _B.submit);
      await tester.pump();
      expect(repo.calls, ['submit']);
    });

    testWidgets('approve reaches the server once', (tester) async {
      await pumpBar(tester, _visit(VisitState.escalated), user: manager);
      await tapButton(tester, _B.approve);
      await tester.pump();
      expect(repo.calls, ['approve']);
    });

    testWidgets('while one action runs, every button is disabled',
        (tester) async {
      repo.actionGate = Completer<void>();
      await pumpBar(tester, _visit(VisitState.submitted), user: manager);
      await tapButton(tester, _B.approve);

      for (final b in _actions(tester)) {
        expect(b.onPressed, isNull, reason: b.label);
      }
      expect(
        tester.widget<AppButton>(button(phoneEn, _B.approve)).loading,
        isTrue,
      );
      expect(
        tester.widget<AppButton>(button(phoneEn, _B.reject)).loading,
        isFalse,
      );

      // A second tap is ignored.
      await tester.tap(button(phoneEn, _B.approve), warnIfMissed: false);
      await tester.tap(button(phoneEn, _B.cancel), warnIfMissed: false);
      await tester.pump();
      expect(repo.calls, ['approve']);

      repo.actionGate!.complete();
      await tester.pump();
      await tester.pump();
      for (final b in _actions(tester)) {
        expect(b.onPressed, isNotNull, reason: b.label);
        expect(b.loading, isFalse);
      }
    });
  });

  group('reject', () {
    testWidgets('asks for a reason; dismissing sends nothing', (tester) async {
      await pumpBar(tester, _visit(VisitState.submitted), user: manager);
      await tapButton(tester, _B.reject);
      await settle(tester);
      expect(find.text(l10n(english).wfRejectReason), findsOneWidget);
      await tester.tap(find.byTooltip(l10n(english).commonClose));
      await settle(tester);
      expect(repo.calls, isEmpty);
      // The bar is usable again.
      expect(
          tester.widget<AppButton>(button(phoneEn, _B.reject)).onPressed,
          isNotNull);
    });

    testWidgets('sends the typed reason', (tester) async {
      await pumpBar(tester, _visit(VisitState.submitted),
          user: manager, surface: phoneAr);
      await tapButton(tester, _B.reject, s: phoneAr);
      await settle(tester);
      await tester.enterText(find.byType(TextField), ' موعد غير مناسب ');
      final submit = find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(AppButton));
      await tester.tap(submit);
      await settle(tester);
      expect(repo.calls, ['reject:موعد غير مناسب']);
    });
  });

  group('cancel', () {
    testWidgets('asks first; "no" sends nothing, "yes" cancels',
        (tester) async {
      await pumpBar(tester, _visit(VisitState.approved));
      final t = l10n(english);
      await tapButton(tester, _B.cancel);
      await settle(tester);
      // The tool keeps its label while it waits, so look inside the dialog.
      Finder inDialog(String text) =>
          find.descendant(of: find.byType(Dialog), matching: find.text(text));
      expect(inDialog(t.wfConfirmCancelTitle), findsOneWidget);
      expect(inDialog(t.wfConfirmCancelMessage), findsOneWidget);
      await tester.tap(find.text(t.commonNo));
      await settle(tester);
      expect(repo.calls, isEmpty);

      await tapButton(tester, _B.cancel);
      await settle(tester);
      await tester.tap(find.text(t.commonYes));
      await settle(tester);
      expect(repo.calls, ['cancel']);
    });
  });

  group('reschedule', () {
    testWidgets('prefills the visit and sends the change', (tester) async {
      final visit = _visit(VisitState.approved);
      await pumpBar(tester, visit);
      final t = l10n(english);
      await tapButton(tester, _B.reschedule);
      await settle(tester);
      expect(find.text('Contract review'), findsOneWidget);
      expect(find.text('Olaya St'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, t.wfFieldPurpose), 'Price talk');
      final submit = find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(AppButton));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await settle(tester);
      expect(repo.calls, [
        'reschedule:${visit.scheduledDatetime!.toIso8601String()}|'
            'Price talk|Olaya St',
      ]);
    });

    testWidgets('no change sends nothing', (tester) async {
      await pumpBar(tester, _visit(VisitState.submitted));
      await tapButton(tester, _B.reschedule);
      await settle(tester);
      await tester.tap(find.byTooltip(l10n(english).commonClose));
      await settle(tester);
      expect(repo.calls, isEmpty);
    });
  });

  group('start', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<void> answerDisclosure(WidgetTester tester, Key key) async {
      await settle(tester);
      expect(find.byType(VisitTrackingDisclosureDialog), findsOneWidget);
      await tester.ensureVisible(find.byKey(key));
      await settle(tester);
      await tester.tap(find.byKey(key));
      await settle(tester);
    }

    testWidgets('the disclosure comes first; declining starts nothing',
        (tester) async {
      sl.registerSingleton<SharedPreferences>(prefs);
      await pumpBar(tester, _visit(VisitState.approved), surface: phoneAr);
      await tapButton(tester, _B.start, s: phoneAr);
      await answerDisclosure(
          tester, WidgetKeys.visitTrackingDisclosureDecline);
      expect(location.acquireCalls, 0, reason: 'no location prompt');
      expect(repo.calls, isEmpty);
      expect(find.text(l10n(arabic).visitTrackingRequired), findsOneWidget);
    });

    testWidgets('agreeing remembers it and starts at the fix, labelled',
        (tester) async {
      sl.registerSingleton<SharedPreferences>(prefs);
      await pumpBar(tester, _visit(VisitState.approved), surface: phoneAr);
      await tapButton(tester, _B.start, s: phoneAr);
      await answerDisclosure(tester, WidgetKeys.visitTrackingDisclosureAgree);
      expect(prefs.getBool(VisitTrackingConsent.key), isTrue);
      expect(location.acquireCalls, 1);
      expect(describer.locales, ['ar'],
          reason: 'the label is stored in the reviewer\'s language');
      expect(repo.calls, [
        'start:24.7136,46.6753|${FakeDescriber.label}|mocked=false',
      ]);
    });

    testWidgets('already agreed: straight to the fix', (tester) async {
      await prefs.setBool(VisitTrackingConsent.key, true);
      sl.registerSingleton<SharedPreferences>(prefs);
      await pumpBar(tester, _visit(VisitState.approved));
      await tapButton(tester, _B.start);
      await settle(tester);
      expect(find.byType(VisitTrackingDisclosureDialog), findsNothing);
      expect(describer.locales, ['en']);
      expect(repo.calls.single, startsWith('start:'));
    });

    for (final (outcome, message) in <(LocationOutcome, String Function(AppLocalizations))>[
      (const LocationPermissionDenied(), (t) => t.errLocationNeededForVisit),
      (const LocationUnavailable('timeout'), (t) => t.errLocationUnavailable),
    ]) {
      testWidgets('${outcome.runtimeType}: says why, starts nothing',
          (tester) async {
        location.outcome = outcome;
        await pumpBar(tester, _visit(VisitState.approved));
        await tapButton(tester, _B.start);
        await settle(tester);
        expect(find.text(message(l10n(english))), findsOneWidget);
        expect(repo.calls, isEmpty);
        expect(describer.locales, isEmpty);
        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        final context = tester.element(find.byType(VisitActionBar));
        expect(snack.backgroundColor, Theme.of(context).colorScheme.error);
      });
    }

    testWidgets('a mocked fix asks first; cancelling aborts the start',
        (tester) async {
      location.outcome =
          const LocationOk(latitude: 1, longitude: 2, isMocked: true);
      await pumpBar(tester, _visit(VisitState.approved));
      await tapButton(tester, _B.start);
      await settle(tester);
      final t = l10n(english);
      expect(find.text(t.wfMockLocationTitle), findsOneWidget);
      await tester.tap(find.text(t.commonCancel));
      await settle(tester);
      expect(repo.calls, isEmpty);
      expect(find.byType(SnackBar), findsNothing,
          reason: 'cancelling was the answer, not an error');
    });

    testWidgets('a mocked fix, confirmed, is sent flagged', (tester) async {
      location.outcome =
          const LocationOk(latitude: 1, longitude: 2, isMocked: true);
      await pumpBar(tester, _visit(VisitState.approved));
      await tapButton(tester, _B.start);
      await settle(tester);
      await tester.tap(find.text(l10n(english).commonContinue));
      await settle(tester);
      expect(repo.calls,
          ['start:1.0,2.0|${FakeDescriber.label}|mocked=true']);
    });

    testWidgets('the start button spins while the fix is taken',
        (tester) async {
      final fix = Completer<LocationOutcome>();
      sl.unregister<LocationService>();
      sl.registerSingleton<LocationService>(_SlowLocation(fix.future));
      await pumpBar(tester, _visit(VisitState.approved));
      await tapButton(tester, _B.start);
      await tester.pump();
      expect(tester.widget<AppButton>(button(phoneEn, _B.start)).loading,
          isTrue);
      expect(
          tester.widget<AppToolButton>(button(phoneEn, _B.cancel)).onPressed,
          isNull);
      fix.complete(const LocationUnavailable());
      await settle(tester);
      expect(tester.widget<AppButton>(button(phoneEn, _B.start)).loading,
          isFalse);
    });
  });

  group('end', () {
    testWidgets('asks for the outcome (prefilled), then ends at the fix',
        (tester) async {
      await pumpBar(
          tester, _visit(VisitState.inProgress, outcome: 'Signed the PO'));
      await tapButton(tester, _B.end);
      await settle(tester);
      expect(find.text('Signed the PO'), findsOneWidget);
      expect(location.acquireCalls, 0, reason: 'the outcome comes first');
      final submit = find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(AppButton));
      await tester.tap(submit);
      await settle(tester);
      expect(location.acquireCalls, 1);
      expect(repo.calls, [
        'end:Signed the PO|24.7136,46.6753|${FakeDescriber.label}|mocked=false',
      ]);
    });

    testWidgets('dismissing the outcome ends nothing', (tester) async {
      await pumpBar(tester, _visit(VisitState.inProgress));
      await tapButton(tester, _B.end);
      await settle(tester);
      await tester.tap(find.byTooltip(l10n(english).commonClose));
      await settle(tester);
      expect(location.acquireCalls, 0);
      expect(repo.calls, isEmpty);
    });

    testWidgets('no fix: says why and ends nothing', (tester) async {
      location.outcome = const LocationPermissionDenied();
      await pumpBar(tester, _visit(VisitState.inProgress, outcome: 'x'));
      await tapButton(tester, _B.end);
      await settle(tester);
      await tester.tap(find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(AppButton)));
      await settle(tester);
      expect(find.text(l10n(english).errLocationNeededForVisit),
          findsOneWidget);
      expect(repo.calls, isEmpty);
    });
  });

  group('attachments', () {
    testWidgets('closing the camera does nothing', (tester) async {
      final calls = _mock(_imagePicker, (_) async => null);
      await pumpBar(tester, _visit(VisitState.inProgress));
      await tapButton(tester, _B.photo);
      await settle(tester);
      expect(calls.single.method, 'pickImage');
      expect((calls.single.arguments as Map)['imageQuality'],
          VisitConstants.photoQuality);
      expect(find.byType(SnackBar), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a broken camera says so', (tester) async {
      _mock(_imagePicker,
          (_) async => throw PlatformException(code: 'no_available_camera'));
      await pumpBar(tester, _visit(VisitState.inProgress), surface: phoneAr);
      await tapButton(tester, _B.photo, s: phoneAr);
      await settle(tester);
      expect(find.text(l10n(arabic).wfCameraUnavailable), findsOneWidget);
    });

    testWidgets('camera access refused: offers the app settings',
        (tester) async {
      _mock(_imagePicker,
          (_) async => throw PlatformException(code: 'camera_access_denied'));
      final settings = _mock(_permissions, (_) async => true);
      await pumpBar(tester, _visit(VisitState.inProgress));
      final t = l10n(english);

      await tapButton(tester, _B.photo);
      await settle(tester);
      expect(find.text(t.wfCameraAccessTitle), findsOneWidget);
      expect(find.text(t.wfCameraAccessMessage), findsOneWidget);
      await tester.tap(find.text(t.commonCancel));
      await settle(tester);
      expect(settings, isEmpty);

      await tapButton(tester, _B.photo);
      await settle(tester);
      await tester.tap(find.text(t.wfOpenSettings));
      await settle(tester);
      expect(settings.single.method, 'openAppSettings');
    });

    testWidgets('closing the file picker does nothing', (tester) async {
      final calls = _mock(_filePicker, (_) async => null);
      await pumpBar(tester, _visit(VisitState.submitted), user: manager);
      await tapButton(tester, _B.file);
      await settle(tester);
      expect(calls.single.method, 'any');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a picked file without a path is unreadable',
        (tester) async {
      _mock(_filePicker, (_) async => [
            {'name': 'cloud.pdf', 'path': null, 'size': 10},
          ]);
      await pumpBar(tester, _visit(VisitState.inProgress));
      await tapButton(tester, _B.file);
      await settle(tester);
      expect(find.text(l10n(english).wfAttachmentUnreadable), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('files access refused: offers the app settings',
        (tester) async {
      _mock(
          _filePicker,
          (_) async =>
              throw PlatformException(code: 'read_external_storage_denied'));
      await pumpBar(tester, _visit(VisitState.inProgress));
      await tapButton(tester, _B.file);
      await settle(tester);
      final t = l10n(english);
      expect(find.text(t.wfFilesAccessTitle), findsOneWidget);
      await tester.tap(find.text(t.commonCancel));
      await settle(tester);
    });

    testWidgets('a broken file picker says so', (tester) async {
      _mock(_filePicker,
          (_) async => throw PlatformException(code: 'unknown_path'));
      await pumpBar(tester, _visit(VisitState.inProgress));
      await tapButton(tester, _B.file);
      await settle(tester);
      expect(find.text(l10n(english).wfFilePickerUnavailable), findsOneWidget);
    });

    testWidgets('a picked file is read off the UI thread and uploaded',
        (tester) async {
      final dir = Directory.systemTemp.createTempSync('visit_bar_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/report.pdf')..writeAsBytesSync([1, 2, 3]);
      _mock(_filePicker, (_) async => [
            {'name': 'report.pdf', 'path': file.path, 'size': 3},
          ]);
      await pumpBar(tester, _visit(VisitState.inProgress));
      await tester.runAsync(() async {
        await tester.tap(button(phoneEn, _B.file));
        // Real file I/O and a background isolate: wait on the real clock.
        for (var i = 0; i < 50 && repo.calls.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await settle(tester);
      expect(repo.calls, ['upload:report.pdf']);
    });

    testWidgets('a missing file is unreadable, not a crash', (tester) async {
      _mock(_filePicker, (_) async => [
            {'name': 'gone.pdf', 'path': '/definitely/not/here.pdf', 'size': 3},
          ]);
      await pumpBar(tester, _visit(VisitState.inProgress));
      await tester.runAsync(() async {
        await tester.tap(button(phoneEn, _B.file));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await settle(tester);
      expect(find.text(l10n(english).wfAttachmentUnreadable), findsOneWidget);
      expect(repo.calls, isEmpty);
    });
  });
}

class _SlowLocation extends FakeLocationService {
  _SlowLocation(this.answer);
  final Future<LocationOutcome> answer;

  @override
  Future<LocationOutcome> acquire({dynamic accuracy}) => answer;
}

enum _Kind { primary, secondary, destructive, tool, destructiveTool }

/// One action in the bar, whichever widget draws it.
class _Action {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final _Kind kind;

  const _Action(this.label, this.onPressed, this.loading, this.icon, this.kind);

  static _Action? of(Widget w) => switch (w) {
        AppButton() => _Action(w.label, w.onPressed, w.loading, w.icon,
            switch (w.variant) {
              AppButtonVariant.primary => _Kind.primary,
              AppButtonVariant.secondary => _Kind.secondary,
              AppButtonVariant.destructive => _Kind.destructive,
            }),
        AppToolButton() => _Action(w.label, w.onPressed, w.loading, w.icon,
            w.destructive ? _Kind.destructiveTool : _Kind.tool),
        _ => null,
      };
}

/// Every action on screen, in tree (reading) order.
List<_Action> _actions(WidgetTester tester) => [
      for (final w in tester.widgetList(
          find.byWidgetPredicate((w) => _Action.of(w) != null)))
        _Action.of(w)!,
    ];
