import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/core/di/service_locator.dart';
import 'package:location_gps/core/location/location_service.dart';
import 'package:location_gps/core/network/pending_actions_queue.dart';
import 'package:location_gps/core/network/server_clock.dart';
import 'package:location_gps/features/visits/bloc/visit_bloc.dart' as vb;
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/visit_tracking_consent.dart';
import 'package:location_gps/features/visits/data/visit_trail_tracker.dart';
import 'package:location_gps/features/visits/domain/visit_action.dart';
import 'package:location_gps/features/visits/view/persistent_visit_bar.dart';
import 'package:location_gps/features/visits/view/visit_labels.dart';
import 'package:location_gps/features/visits/view/visit_tracking_disclosure_dialog.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';
import 'package:location_gps/shared/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

final _start = fixtureDay;

Visit _running({int id = 5, String? customer = LongText.arabicCompany}) =>
    Visit(
      id: id,
      partnerName: customer,
      state: VisitState.inProgress,
      startDatetime: _start,
    );

PendingAction _queuedStart(int visitId) => PendingAction(
      visitId: visitId,
      payload: {QueuedVisitActionFields.type: VisitAction.start.name},
      queuedAt: _start,
    );

void main() {
  setUpAll(initHarness);

  late StubVisitBloc bloc;
  late FixedServerClock clock;
  late FakeTrailTracker tracker;
  late FakeLocationService location;
  late SharedPreferences prefs;

  setUp(() async {
    bloc = StubVisitBloc();
    clock = FixedServerClock(
        _start.add(const Duration(hours: 1, minutes: 2, seconds: 3)));
    tracker = FakeTrailTracker();
    location = FakeLocationService();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    sl.registerSingleton<ServerClock>(clock);
  });

  tearDown(() async {
    await bloc.close();
    await sl.reset();
  });

  Future<List<int>> pumpBar(
    WidgetTester tester, {
    vb.VisitState? state,
    Surface surface = phoneEn,
  }) async {
    final taps = <int>[];
    if (state != null) bloc.push(state);
    await pumpSurface(
      tester,
      surface,
      withBlocs(
        visit: bloc,
        Align(
          alignment: Alignment.bottomCenter,
          child: PersistentVisitBar(onTap: () => taps.add(1)),
        ),
      ),
    );
    return taps;
  }

  void recording(int visitId, [TrailPause? paused]) =>
      tracker.statusNotifier.value =
          TrailCaptureStatus(visitId: visitId, paused: paused);

  group('layout', () {
    testOnEverySurface(
      'a long customer and a paused-trail line with its resume button',
      (s) {
        sl.registerSingleton<VisitTrailTracker>(tracker);
        recording(5, TrailPause.permission);
        bloc.push(vb.VisitState.running(_running()));
        return withBlocs(
          visit: bloc,
          Align(
            alignment: Alignment.bottomCenter,
            child: PersistentVisitBar(onTap: () {}),
          ),
        );
      },
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.text('01:02:03'), findsOneWidget);
        expect(find.text(t.trailStatusNoPermission), findsOneWidget);
        expect(find.text(t.trailStatusResume), findsOneWidget);
        final customer = tester.widget<Text>(find.text(LongText.arabicCompany));
        expect(customer.maxLines, 1);
        expect(customer.overflow, TextOverflow.ellipsis);
        final status =
            tester.widget<Text>(find.text(t.trailStatusNoPermission));
        expect(status.maxLines, 2);
      },
    );
  });

  group('showing and hiding', () {
    testWidgets('idle: nothing on screen', (tester) async {
      await pumpBar(tester);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a running visit without a start time stays hidden',
        (tester) async {
      await pumpBar(
        tester,
        state: const vb.VisitState.running(
            Visit(id: 5, state: VisitState.inProgress)),
      );
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('slides in when a visit starts and out when it ends',
        (tester) async {
      await pumpBar(tester);
      bloc.push(vb.VisitState.running(_running()));
      await tester.pump();
      await tester.pump(AppDurations.base ~/ 2);
      final half = tester.getSize(find.byType(PersistentVisitBar)).height;
      await tester.pump(AppDurations.base);
      final full = tester.getSize(find.byType(PersistentVisitBar)).height;
      expect(half, lessThan(full));
      expect(find.text(LongText.arabicCompany), findsOneWidget);

      bloc.push(const vb.VisitState());
      await tester.pump();
      await tester.pump(AppDurations.base * 2);
      expect(find.text(LongText.arabicCompany), findsNothing);
      expect(tester.getSize(find.byType(PersistentVisitBar)).height, 0);
    });

    testWidgets('switching visits swaps the bar content', (tester) async {
      await pumpBar(tester, state: vb.VisitState.running(_running()));
      bloc.push(vb.VisitState.running(_running(id: 6, customer: 'Acme')));
      await tester.pump();
      await tester.pump(AppDurations.base * 2);
      expect(find.text('Acme'), findsOneWidget);
      expect(find.text(LongText.arabicCompany), findsNothing);
    });

    testWidgets('no customer: no customer line', (tester) async {
      await pumpBar(
          tester, state: vb.VisitState.running(_running(customer: null)));
      expect(find.text('01:02:03'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
      expectCleanLayout(tester);
    });
  });

  group('the bar', () {
    testWidgets('a tap fires onTap once', (tester) async {
      final taps = await pumpBar(
          tester, state: vb.VisitState.running(_running()));
      await tester.tap(find.byType(PersistentVisitBar));
      await tester.pump();
      expect(taps, [1]);
      expect(tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(kMinInteractiveDimension));
    });

    for (final s in const [phoneEn, phoneAr]) {
      testWidgets('the chevron points forward — ${s.name}', (tester) async {
        await pumpBar(
            tester, state: vb.VisitState.running(_running()), surface: s);
        final icon = tester.widget<Icon>(find.byWidgetPredicate((w) =>
            w is Icon &&
            (w.icon == Icons.chevron_right || w.icon == Icons.chevron_left)));
        final direction =
            Directionality.of(tester.element(find.byType(PersistentVisitBar)));
        expect(chevronPointsToEnd(icon.icon!, direction), isTrue);
      });
    }

    testWidgets('the timer is green, tabular, and ticks every second',
        (tester) async {
      await pumpBar(tester, state: vb.VisitState.running(_running()));
      final context = tester.element(find.byType(PersistentVisitBar));
      final text = tester.widget<Text>(find.text('01:02:03'));
      expect(text.style?.color, context.visitSuccess);
      expect(text.style?.fontFeatures,
          contains(const FontFeature.tabularFigures()));

      clock.current = clock.current.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:02:04'), findsOneWidget);

      clock.current = clock.current.add(const Duration(hours: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('31:02:04'), findsOneWidget,
          reason: 'hours are not wrapped at a day');
    });

    testWidgets('a device clock behind the start shows zero, not negative',
        (tester) async {
      clock.current = _start.subtract(const Duration(minutes: 3));
      await pumpBar(tester, state: vb.VisitState.running(_running()));
      expect(find.text('00:00:00'), findsOneWidget);
    });

    testWidgets('a corrected start time restarts the count', (tester) async {
      await pumpBar(tester, state: vb.VisitState.running(_running()));
      final corrected = Visit(
        id: 5,
        partnerName: LongText.arabicCompany,
        state: VisitState.inProgress,
        startDatetime: _start.add(const Duration(hours: 1)),
      );
      bloc.push(vb.VisitState.running(corrected));
      await tester.pump();
      expect(find.text('00:02:03'), findsOneWidget);
    });

    testWidgets('the live dot pulses and the device can idle between beats',
        (tester) async {
      await pumpBar(tester, state: vb.VisitState.running(_running()));
      expect(find.byType(AmbientPulse), findsOneWidget);
      // One beat and its rest: no exception, the bar is still there.
      await pumpFrames(tester, const Duration(seconds: 4));
      expect(find.byType(AmbientPulse), findsOneWidget);
      expectCleanLayout(tester);
    });
  });

  group('the trail status line', () {
    Finder resume(Surface s) => find.text(l10n(s.locale).trailStatusResume);

    testWidgets('without a tracker: no line', (tester) async {
      await pumpBar(tester, state: vb.VisitState.running(_running()));
      expect(find.byType(TextButton), findsNothing);
      expect(find.text(l10n(english).trailStatusRecording), findsNothing);
    });

    testWidgets('recording: a quiet line, no button', (tester) async {
      sl.registerSingleton<VisitTrailTracker>(tracker);
      recording(5);
      await pumpBar(tester, state: vb.VisitState.running(_running()));
      final t = l10n(english);
      final line = tester.widget<Text>(find.text(t.trailStatusRecording));
      final context = tester.element(find.byType(PersistentVisitBar));
      expect(line.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
      expect(resume(phoneEn), findsNothing);
    });

    testWidgets('follows the tracker live', (tester) async {
      sl.registerSingleton<VisitTrailTracker>(tracker);
      recording(5);
      await pumpBar(tester,
          state: vb.VisitState.running(_running()), surface: phoneAr);
      final t = l10n(arabic);
      expect(find.text(t.trailStatusRecording), findsOneWidget);

      recording(5, TrailPause.unavailable);
      await tester.pump();
      expect(find.text(t.trailStatusUnavailable), findsOneWidget);
      final context = tester.element(find.byType(PersistentVisitBar));
      expect(
        tester.widget<Text>(find.text(t.trailStatusUnavailable)).style?.color,
        context.visitWarning,
      );
      expect(resume(phoneAr), findsOneWidget);
    });

    for (final (pause, label) in <(TrailPause, String Function(AppLocalizations))>[
      (TrailPause.consent, (t) => t.trailStatusNoConsent),
      (TrailPause.permission, (t) => t.trailStatusNoPermission),
      (TrailPause.unavailable, (t) => t.trailStatusUnavailable),
    ]) {
      testWidgets('paused for ${pause.name}: says why', (tester) async {
        sl.registerSingleton<VisitTrailTracker>(tracker);
        recording(5, pause);
        await pumpBar(tester, state: vb.VisitState.running(_running()));
        expect(find.text(label(l10n(english))), findsOneWidget);
        expect(resume(phoneEn), findsOneWidget);
      });
    }

    testWidgets('another visit being recorded: nothing to say',
        (tester) async {
      sl.registerSingleton<VisitTrailTracker>(tracker);
      recording(99);
      await pumpBar(tester, state: vb.VisitState.running(_running()));
      expect(find.text(l10n(english).trailStatusRecording), findsNothing);
      expect(find.text(l10n(english).trailStatusWaitingSync), findsNothing);
    });

    testWidgets('a start still queued offline says it will sync',
        (tester) async {
      sl.registerSingleton<VisitTrailTracker>(tracker);
      sl.registerSingleton<PendingActionsQueue>(
          FakePendingQueue([_queuedStart(99), _queuedStart(5)]));
      await pumpBar(tester, state: vb.VisitState.running(_running()));
      expect(find.text(l10n(english).trailStatusWaitingSync), findsOneWidget);
      expect(resume(phoneEn), findsNothing);
    });

    testWidgets('only a queued start counts, and only for this visit',
        (tester) async {
      sl.registerSingleton<VisitTrailTracker>(tracker);
      sl.registerSingleton<PendingActionsQueue>(FakePendingQueue([
        _queuedStart(99),
        PendingAction(
          visitId: 5,
          payload: {QueuedVisitActionFields.type: VisitAction.end.name},
          queuedAt: _start,
        ),
      ]));
      await pumpBar(tester, state: vb.VisitState.running(_running()));
      expect(find.text(l10n(english).trailStatusWaitingSync), findsNothing);
    });

    group('resume', () {
      testWidgets('unavailable: retries once', (tester) async {
        sl.registerSingleton<VisitTrailTracker>(tracker);
        recording(5, TrailPause.unavailable);
        await pumpBar(tester, state: vb.VisitState.running(_running()));
        await tester.tap(resume(phoneEn));
        await tester.pump();
        expect(tracker.retryCalls, 1);
      });

      testWidgets('consent: agreeing records it and retries', (tester) async {
        sl.registerSingleton<VisitTrailTracker>(tracker);
        sl.registerSingleton<SharedPreferences>(prefs);
        recording(5, TrailPause.consent);
        await pumpBar(tester, state: vb.VisitState.running(_running()));
        await tester.tap(resume(phoneEn));
        await tester.pumpAndSettle();
        expect(find.byType(VisitTrackingDisclosureDialog), findsOneWidget);
        expect(tracker.retryCalls, 0);

        final agree = find.byKey(WidgetKeys.visitTrackingDisclosureAgree);
        await tester.ensureVisible(agree);
        await tester.pumpAndSettle();
        await tester.tap(agree);
        await tester.pumpAndSettle();
        expect(prefs.getBool(VisitTrackingConsent.key), isTrue);
        expect(tracker.retryCalls, 1);
      });

      testWidgets('consent: declining retries nothing', (tester) async {
        sl.registerSingleton<VisitTrailTracker>(tracker);
        sl.registerSingleton<SharedPreferences>(prefs);
        recording(5, TrailPause.consent);
        await pumpBar(tester, state: vb.VisitState.running(_running()));
        await tester.tap(resume(phoneEn));
        await tester.pumpAndSettle();
        final decline = find.byKey(WidgetKeys.visitTrackingDisclosureDecline);
        await tester.ensureVisible(decline);
        await tester.pumpAndSettle();
        await tester.tap(decline);
        await tester.pumpAndSettle();
        expect(tracker.retryCalls, 0);
        expect(prefs.getBool(VisitTrackingConsent.key), isNull);
      });

      testWidgets('permission granted: asks, then retries', (tester) async {
        sl.registerSingleton<VisitTrailTracker>(tracker);
        sl.registerSingleton<LocationService>(location);
        recording(5, TrailPause.permission);
        await pumpBar(tester, state: vb.VisitState.running(_running()));
        await tester.tap(resume(phoneEn));
        await tester.pump();
        expect(location.requestAccessCalls, 1);
        expect(tracker.retryCalls, 1);
        expect(location.appSettingsCalls + location.locationSettingsCalls, 0);
      });

      testWidgets('permission denied for good: opens app settings only',
          (tester) async {
        sl.registerSingleton<VisitTrailTracker>(tracker);
        location.access = LocationAccess.deniedForever;
        sl.registerSingleton<LocationService>(location);
        recording(5, TrailPause.permission);
        await pumpBar(tester, state: vb.VisitState.running(_running()));
        await tester.tap(resume(phoneEn));
        await tester.pump();
        expect(location.appSettingsCalls, 1);
        expect(tracker.retryCalls, 0);
      });

      testWidgets('location switched off: opens location settings only',
          (tester) async {
        sl.registerSingleton<VisitTrailTracker>(tracker);
        location.access = LocationAccess.serviceDisabled;
        sl.registerSingleton<LocationService>(location);
        recording(5, TrailPause.permission);
        await pumpBar(tester, state: vb.VisitState.running(_running()));
        await tester.tap(resume(phoneEn));
        await tester.pump();
        expect(location.locationSettingsCalls, 1);
        expect(tracker.retryCalls, 0);
      });

      testWidgets('permission with no location service: does nothing',
          (tester) async {
        sl.registerSingleton<VisitTrailTracker>(tracker);
        recording(5, TrailPause.permission);
        await pumpBar(tester, state: vb.VisitState.running(_running()));
        await tester.tap(resume(phoneEn));
        await tester.pump();
        expect(tracker.retryCalls, 0);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the resume button is a full tap target', (tester) async {
        sl.registerSingleton<VisitTrailTracker>(tracker);
        recording(5, TrailPause.unavailable);
        await pumpBar(tester,
            state: vb.VisitState.running(_running()), surface: surfaces[0]);
        expect(
          tester.getSize(find.byType(TextButton)).height,
          greaterThanOrEqualTo(kMinInteractiveDimension),
        );
      });
    });
  });
}
