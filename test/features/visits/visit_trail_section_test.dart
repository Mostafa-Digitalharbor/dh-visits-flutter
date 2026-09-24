import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_error_messages.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/core/utils/app_date.dart';
import 'package:location_gps/core/utils/app_number.dart';
import 'package:location_gps/core/utils/duration_format.dart';
import 'package:location_gps/features/visits/bloc/visit_trail_cubit.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/visits/view/visit_detail_row.dart';
import 'package:location_gps/features/visits/view/visit_labels.dart';
import 'package:location_gps/features/visits/view/visit_section.dart';
import 'package:location_gps/features/visits/view/visit_trail_section.dart';
import 'package:location_gps/shared/widgets/widgets.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

Visit _visit({bool running = true, bool started = true}) => Visit(
      id: 5,
      state: running ? VisitState.inProgress : VisitState.done,
      startDatetime: started ? fixtureDay : null,
    );

/// The first row labelled [label] (an empty trail has two under the map
/// title: the count and the reason).
VisitDetailRow _row(WidgetTester tester, String label) =>
    tester.widget<VisitDetailRow>(find
        .byWidgetPredicate((w) => w is VisitDetailRow && w.label == label)
        .first);

List<String> _labels(WidgetTester tester) => [
      for (final r
          in tester.widgetList<VisitDetailRow>(find.byType(VisitDetailRow)))
        r.label,
    ];

VisitTrailCubit _cubitOf(WidgetTester tester) =>
    tester.element(find.byType(VisitTrailSection)).read<VisitTrailCubit>();

void main() {
  setUpAll(initHarness);

  late FakeVisitsRepo repo;
  late FakeTrailTracker tracker;

  setUp(() {
    repo = FakeVisitsRepo(track: trackOf(5, 6, km: 2.345));
    tracker = FakeTrailTracker();
  });

  /// The section under a cubit the tree owns (and closes on unmount), created
  /// inside the test so its poll timer runs on the test clock.
  Widget section({
    Visit? visit,
    VoidCallback? onOpenTrail,
    bool withTracker = false,
  }) {
    final v = visit ?? _visit();
    return BlocProvider(
      // A fresh cubit per pump, even at the same place in the tree.
      key: UniqueKey(),
      create: (_) => VisitTrailCubit(
        repository: repo,
        visitId: v.id,
        tracker: withTracker ? tracker : null,
        live: v.isTrackingLive,
      )..load(),
      child: VisitTrailSection(visit: v, onOpenTrail: onOpenTrail),
    );
  }

  group('layout', () {
    testOnEverySurface(
      'a running trail with every row and a pending-upload chip',
      (s) {
        tracker.pendingNotifier.value = 1234;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: section(withTracker: true, onOpenTrail: () {}),
        );
      },
      scrollable: true,
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.text(t.trailSectionTitle), findsWidgets);
        expect(find.text('1,234'), findsOneWidget);
        expect(_labels(tester), [
          t.trailMapTitle,
          t.trailDistance,
          t.trailAvgSpeed,
          t.wfDurationLabel,
          t.trailLastFix,
          t.trailSectionTitle,
        ]);
      },
    );

    testOnEverySurface(
      'a failed read with its retry',
      (s) {
        repo.onReadTrack = (_) async => throw ApiException(
              code: ApiErrorCode.validation,
              serverMessage: LongText.of(s) * 2,
            );
        return Padding(
          padding: const EdgeInsets.all(16),
          child: section(),
        );
      },
      scrollable: true,
      verify: (tester, s) async {
        expect(find.byTooltip(l10n(s.locale).commonRetry), findsOneWidget);
      },
    );
  });

  group('hidden states', () {
    testWidgets('a visit never started renders nothing, needs no cubit',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        VisitTrailSection(visit: _visit(started: false)),
      );
      expect(find.byType(VisitSection), findsNothing);
      expect(tester.takeException(), isNull);
      expect(repo.readTrackCalls, 0);
    });

    testWidgets('loading with nothing yet says nothing (no "0 points")',
        (tester) async {
      final pending = Completer<VisitTrack>();
      repo.onReadTrack = (_) => pending.future;
      await pumpSurface(tester, phoneEn, section());
      expect(find.byType(VisitSection), findsNothing);
      expect(find.textContaining('0'), findsNothing);
    });
  });

  group('failure', () {
    testWidgets('says why, localized, and retry reloads once',
        (tester) async {
      var fail = true;
      repo.onReadTrack = (_) async {
        if (fail) throw ApiException(code: ApiErrorCode.network);
        return trackOf(5, 3);
      };
      await pumpSurface(tester, phoneAr, section());
      final t = l10n(arabic);
      final row = _row(tester, t.trailMapTitle);
      expect(row.value, ApiException(code: ApiErrorCode.network).messageFor(t));
      final context = tester.element(find.byType(VisitTrailSection));
      expect(row.iconColor, Theme.of(context).colorScheme.error);
      expect(repo.readTrackCalls, 1);

      fail = false;
      await tester.tap(find.byTooltip(t.commonRetry));
      await tester.pump();
      await tester.pump();
      expect(repo.readTrackCalls, 2);
      expect(_row(tester, t.trailMapTitle).value, t.trailPoints(3));
      expect(find.byTooltip(t.commonRetry), findsNothing);
    });

    testWidgets('an unexpected error reads as unknown', (tester) async {
      repo.onReadTrack = (_) async => throw StateError('boom');
      await pumpSurface(tester, phoneEn, section());
      expect(
        _row(tester, l10n(english).trailMapTitle).value,
        ApiException.unexpected(StateError('boom'))
            .messageFor(l10n(english)),
      );
    });

    testWidgets('the retry button is a full tap target', (tester) async {
      repo.onReadTrack = (_) async => throw ApiException(code: ApiErrorCode.timeout);
      await pumpSurface(tester, surfaces[0], section());
      final button = find.ancestor(
        of: find.byTooltip(l10n(arabic).commonRetry),
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(button).height,
          greaterThanOrEqualTo(kMinInteractiveDimension));
    });
  });

  group('empty trail', () {
    testWidgets('running: zero points, "recording", and why it is empty',
        (tester) async {
      repo.track = const VisitTrack(visitId: 5);
      await pumpSurface(tester, phoneEn, section());
      final t = l10n(english);
      expect(_labels(tester), [t.trailMapTitle, t.trailMapTitle]);
      expect(_row(tester, t.trailMapTitle).value, t.trailPoints(0));
      expect(find.text(t.trailEmptyRunning), findsOneWidget);
      expect(find.text(t.trailLive), findsOneWidget);
      final context = tester.element(find.byType(VisitTrailSection));
      final pill = tester.widget<TonePill>(find.byType(TonePill));
      expect(pill.color, context.visitSuccess);
      expect(find.byType(Tooltip), findsNothing,
          reason: 'nothing waiting: the chip is not a button');
    });

    testWidgets('finished: no chip, the finished wording', (tester) async {
      repo.track = const VisitTrack(visitId: 5);
      await pumpSurface(
          tester, phoneAr, section(visit: _visit(running: false)));
      final t = l10n(arabic);
      expect(find.text(t.trailEmptyFinished), findsOneWidget);
      expect(find.text(t.trailEmptyRunning), findsNothing);
      expect(find.byType(TonePill), findsNothing);
      expect(_row(tester, t.trailMapTitle).iconColor, isNull);
    });
  });

  group('with points', () {
    testWidgets('lists points, distance, speed, duration and the last fix',
        (tester) async {
      await pumpSurface(tester, phoneEn, section(visit: _visit(running: false)),
          scrollable: true);
      final t = l10n(english);
      final context = tester.element(find.byType(VisitTrailSection));
      final track = repo.track;
      expect(_row(tester, t.trailMapTitle).value, t.trailPoints(6));
      expect(_row(tester, t.trailDistance).value,
          AppNumber.km(t, 2.345, precise: true));
      expect(_row(tester, t.trailAvgSpeed).value,
          AppNumber.speedKmh(t, track.averageSpeedKmh!));
      expect(_row(tester, t.wfDurationLabel).value,
          const Duration(minutes: 5).localized(context));
      expect(
        _row(tester, t.trailLastFix).value,
        AppDate.dateTimeFormat(context).format(track.lastFixAt!.toLocal()),
      );
    });

    testWidgets('the full-trail row opens it, once', (tester) async {
      var opens = 0;
      await pumpSurface(
          tester, phoneEn, section(onOpenTrail: () => opens++),
          scrollable: true);
      final t = l10n(english);
      final row = _row(tester, t.trailSectionTitle);
      expect(row.value, t.trailOpenFull);
      await tester.ensureVisible(find.text(t.trailOpenFull));
      await tester.tap(find.text(t.trailOpenFull));
      await tester.pump();
      expect(opens, 1);
    });

    testWidgets('no opener, or a single point: no full-trail row',
        (tester) async {
      final t = l10n(english);
      await pumpSurface(tester, phoneEn, section(), scrollable: true);
      expect(find.text(t.trailOpenFull), findsNothing);

      repo.track = trackOf(5, 1);
      await pumpSurface(
          tester, phoneEn, section(onOpenTrail: () {}, visit: _visit()),
          scrollable: true);
      await tester.pump();
      expect(find.text(t.trailOpenFull), findsNothing);
      // One fix: a count and a time, but no distance, speed or duration.
      expect(_labels(tester), [t.trailMapTitle, t.trailLastFix]);
    });

    testWidgets('a zero distance hides distance and speed', (tester) async {
      repo.track = VisitTrack(
        visitId: 5,
        locationLogCount: 3,
        logs: trailLogs(3),
      );
      await pumpSurface(tester, phoneEn, section(), scrollable: true);
      final t = l10n(english);
      expect(_labels(tester),
          [t.trailMapTitle, t.wfDurationLabel, t.trailLastFix]);
    });
  });

  group('pending uploads', () {
    testWidgets('the chip shows the count and uploads on tap',
        (tester) async {
      tracker.pendingNotifier.value = 3;
      await pumpSurface(tester, phoneEn, section(withTracker: true),
          scrollable: true);
      final t = l10n(english);
      expect(find.text('3'), findsOneWidget);
      expect(find.byTooltip(t.trailPendingUploads(3)), findsOneWidget);
      final context = tester.element(find.byType(VisitTrailSection));
      expect(tester.widget<TonePill>(find.byType(TonePill)).color,
          Theme.of(context).colorScheme.tertiary);

      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tracker.drainCalls, 1);
      expect(tracker.flushCalls, 1);
      expect(find.text(t.trailUploadDone), findsOneWidget);
      // The count is gone: back to "recording".
      expect(find.text(t.trailLive), findsOneWidget);
    });

    testWidgets('fixes still stuck: says how many, as an error',
        (tester) async {
      tracker.pendingNotifier.value = 9;
      tracker.pendingAfterFlush = 4;
      await pumpSurface(tester, phoneAr, section(withTracker: true),
          scrollable: true);
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final t = l10n(arabic);
      expect(find.text(t.trailUploadStillPending(4)), findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      final context = tester.element(find.byType(VisitTrailSection));
      expect(snack.backgroundColor, Theme.of(context).colorScheme.error);
    });

    testWidgets('a finished visit shows no chip even with fixes waiting',
        (tester) async {
      tracker.pendingNotifier.value = 3;
      await pumpSurface(
        tester,
        phoneEn,
        section(withTracker: true, visit: _visit(running: false)),
        scrollable: true,
      );
      expect(find.byType(TonePill), findsNothing);
    });

    testWidgets('the count follows the device buffer live', (tester) async {
      await pumpSurface(tester, phoneEn, section(withTracker: true),
          scrollable: true);
      expect(find.text(l10n(english).trailLive), findsOneWidget);
      tracker.pendingNotifier.value = 12;
      await tester.pump();
      expect(find.text('12'), findsOneWidget);
    });
  });

  group('live refresh', () {
    testWidgets('a running visit re-reads its growing trail on the poll',
        (tester) async {
      var fixes = 3;
      repo.onReadTrack = (_) async => trackOf(5, fixes);
      await pumpSurface(tester, phoneEn, section(), scrollable: true);
      final t = l10n(english);
      expect(_row(tester, t.trailMapTitle).value, t.trailPoints(3));

      fixes = 7;
      await tester.pump(AppConstants.trailLiveRefreshInterval);
      await tester.pump();
      expect(repo.readTrackCalls, 2);
      expect(_row(tester, t.trailMapTitle).value, t.trailPoints(7));
    });

    testWidgets('a failed poll keeps the path on screen', (tester) async {
      var fail = false;
      repo.onReadTrack = (_) async {
        if (fail) throw ApiException(code: ApiErrorCode.network);
        return trackOf(5, 4);
      };
      await pumpSurface(tester, phoneEn, section(), scrollable: true);
      fail = true;
      await tester.pump(AppConstants.trailLiveRefreshInterval);
      await tester.pump();
      final t = l10n(english);
      expect(_row(tester, t.trailMapTitle).value, t.trailPoints(4));
      expect(find.byTooltip(t.commonRetry), findsNothing);
    });

    testWidgets('a landed upload refetches straight away', (tester) async {
      await pumpSurface(tester, phoneEn, section(withTracker: true),
          scrollable: true);
      expect(repo.readTrackCalls, 1);
      repo.track = trackOf(5, 9);
      tracker.revisionNotifier.value++;
      await tester.pump();
      await tester.pump();
      expect(repo.readTrackCalls, 2);
      expect(_row(tester, l10n(english).trailMapTitle).value,
          l10n(english).trailPoints(9));
    });

    testWidgets('a finished visit is read once and never polled',
        (tester) async {
      await pumpSurface(tester, phoneEn, section(visit: _visit(running: false)),
          scrollable: true);
      await tester.pump(AppConstants.trailLiveRefreshInterval * 3);
      expect(repo.readTrackCalls, 1);
      expect(_cubitOf(tester).live, isFalse);
    });
  });
}
