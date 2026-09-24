import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_gps/core/api/api_error_messages.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/core/di/service_locator.dart';
import 'package:location_gps/core/map_matching/route_matcher.dart';
import 'package:location_gps/core/utils/app_date.dart';
import 'package:location_gps/core/utils/app_number.dart';
import 'package:location_gps/core/utils/duration_format.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/visits/data/visit_trail_tracker.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:location_gps/features/visits/view/visit_trail_page.dart';
import 'package:location_gps/shared/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:location_gps/shared/extensions/context_extensions.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

const _running = Visit(id: 5, state: VisitState.inProgress);
const _finished = Visit(id: 5, state: VisitState.done);

/// A point well away from the fixture trail (Cairo).
const _far = LatLng(30.04, 31.23);

const _landscapeEn =
    Surface('landscape · en', size: Size(720, 360), locale: english);

/// Fixes from every source, with and without accuracy and speed.
VisitTrack _mixedTrack() {
  final at = fixtureDay;
  return VisitTrack(
    visitId: 5,
    locationLogCount: 4,
    trackedDistanceKm: 1.25,
    logs: [
      VisitLocationLog(
        id: 1,
        loggedAt: at,
        latitude: 24.70,
        longitude: 46.67,
        accuracy: 8,
        source: TrailSource.start,
        location: 'Olaya St',
      ),
      VisitLocationLog(
        id: 2,
        loggedAt: at.add(const Duration(minutes: 3)),
        latitude: 24.71,
        longitude: 46.68,
        accuracy: 0,
        speed: 0,
        source: TrailSource.track,
      ),
      VisitLocationLog(
        id: 3,
        loggedAt: at.add(const Duration(minutes: 6)),
        latitude: 24.72,
        longitude: 46.69,
        speed: 10,
        source: TrailSource.manual,
      ),
      VisitLocationLog(
        id: 4,
        loggedAt: at.add(const Duration(minutes: 9, seconds: 30)),
        latitude: 24.73,
        longitude: 46.70,
        source: TrailSource.end,
      ),
    ],
  );
}

void main() {
  setUpAll(initHarness);

  late FakeVisitsRepo repo;
  late FakeTrailTracker tracker;

  setUp(() {
    repo = FakeVisitsRepo(track: trackOf(5, 8));
    tracker = FakeTrailTracker();
    sl.registerSingleton<VisitsRepository>(repo);
  });

  tearDown(() => sl.reset());

  void withTracker() => sl.registerSingleton<VisitTrailTracker>(tracker);
  void withMatching() => sl.registerSingleton<RouteMatcher>(
      RouteMatcher(matcher: NoRoadMatcher(), requestSpacing: Duration.zero));

  Future<void> pumpPage(
    WidgetTester tester, {
    Visit visit = _finished,
    Surface surface = phoneEn,
  }) =>
      pumpSurface(
        tester,
        surface,
        VisitTrailPage(key: UniqueKey(), visit: visit),
        wrapInScaffold: false,
      );

  group('layout', () {
    testMapOnEverySurface(
      'a long running trail: map, stats and the fix list',
      (s) {
        withTracker();
        withMatching();
        tracker.pendingNotifier.value = 27;
        repo.track = VisitTrack(
          visitId: 5,
          locationLogCount: 40,
          trackedDistanceKm: 12345.678,
          logs: trailLogs(40, location: LongText.of(s) * 2),
        );
        return const VisitTrailPage(visit: _running);
      },
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.byType(AppMap), findsOneWidget);
        expect(find.text(t.trailDistance), findsOneWidget);
        expect(find.byType(RouteLineToggle), findsOneWidget);
        expect(find.byTooltip(t.trailPendingUploads(27)), findsOneWidget);
        final subtitle = tester.widget<Text>(find
            .descendant(
                of: find.byType(ListTile).first,
                matching: find.byType(Text))
            .last);
        expect(subtitle.maxLines, 2);
        expect(subtitle.overflow, TextOverflow.ellipsis);
      },
    );

    testOnEverySurface(
      'empty and running',
      (s) {
        repo.track = const VisitTrack(visitId: 5);
        return const VisitTrailPage(visit: _running);
      },
      verify: (tester, s) async {
        expect(find.text(l10n(s.locale).trailEmptyRunning), findsOneWidget);
      },
    );

    testOnEverySurface(
      'a failed first read',
      (s) {
        repo.onReadTrack = (_) async => throw ApiException(
            code: ApiErrorCode.validation, serverMessage: LongText.of(s));
        return const VisitTrailPage(visit: _finished);
      },
      verify: (tester, s) async {
        expect(find.byType(ErrorView), findsOneWidget);
        expect(find.text(LongText.of(s)), findsOneWidget);
      },
    );
  });

  group('states', () {
    testWidgets('the first read shows a spinner, titled', (tester) async {
      final pending = Completer<VisitTrack>();
      repo.onReadTrack = (_) => pending.future;
      await pumpPage(tester, surface: phoneAr);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n(arabic).trailSectionTitle), findsOneWidget);
      expect(find.byType(AppMap), findsNothing);
    });

    testWidgets('a failed read offers a retry that reads again',
        (tester) async {
      var fail = true;
      repo.onReadTrack = (_) async {
        if (fail) throw ApiException(code: ApiErrorCode.network);
        return const VisitTrack(visitId: 5);
      };
      await pumpPage(tester);
      final t = l10n(english);
      expect(
        find.text(ApiException(code: ApiErrorCode.network).messageFor(t)),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(find.text(t.commonRetry));
      await tester.pump();
      await tester.pump();
      expect(repo.readTrackCalls, 2);
      expect(find.byType(ErrorView), findsNothing);
      expect(find.text(t.trailEmptyFinished), findsOneWidget);
    });

    for (final (visit, wording) in [
      (_running, 'running'),
      (_finished, 'finished'),
    ]) {
      testWidgets('an empty $wording trail says so', (tester) async {
        repo.track = const VisitTrack(visitId: 5);
        await pumpPage(tester, visit: visit);
        final t = l10n(english);
        expect(find.byType(EmptyView), findsOneWidget);
        expect(
          find.text(visit.isTrackingLive
              ? t.trailEmptyRunning
              : t.trailEmptyFinished),
          findsOneWidget,
        );
        expect(find.byType(AppMap), findsNothing);
      });
    }
  });

  group('with points', () {
    testMapWidgets('stats: distance, fix count, duration and speed',
        (tester) async {
      repo.track = _mixedTrack();
      await pumpPage(tester);
      final t = l10n(english);
      final context = tester.element(find.byType(Scaffold).first);
      final track = repo.track;
      expect(find.text(AppNumber.km(t, 1.25, precise: true)), findsOneWidget);
      expect(find.text(AppNumber.whole(4)), findsOneWidget);
      expect(
          find.text(track.span!.localized(context)), findsOneWidget);
      expect(find.text(AppNumber.speedKmh(t, track.averageSpeedKmh!)),
          findsOneWidget);
      for (final label in [
        t.trailDistance,
        t.trailPointsList,
        t.wfDurationLabel,
        t.trailAvgSpeed,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testMapWidgets('a single fix: no duration and no speed', (tester) async {
      repo.track = trackOf(5, 1);
      await pumpPage(tester);
      final t = l10n(english);
      expect(find.text(t.wfDurationLabel), findsNothing);
      expect(find.text(t.trailAvgSpeed), findsNothing);
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byType(RouteLineToggle), findsNothing);
    });

    testMapWidgets('the fix list runs newest first, with each source named',
        (tester) async {
      repo.track = _mixedTrack();
      await pumpPage(tester, surface: phoneAr);
      final t = l10n(arabic);
      final context = tester.element(find.byType(Scaffold).first);
      final tf = AppDate.timeWithSecondsFormat(context);
      final sep = t.commonListSeparator;
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tiles, hasLength(4));
      String titleOf(ListTile tile) => (tile.title! as Text).data!;
      String subtitleOf(ListTile tile) => (tile.subtitle! as Text).data!;
      final logs = repo.track.logs;
      expect(tiles.map(titleOf),
          [for (final l in logs.reversed) tf.format(l.loggedAt.toLocal())]);
      expect(tiles.map(subtitleOf), [
        t.trailPointEnd,
        '${t.trailPointManual}$sep${AppNumber.speedKmh(t, 36)}',
        // Zero accuracy and zero speed are "not reported".
        t.trailPointTrack,
        // A Latin address on an Arabic screen is isolated so the line keeps
        // the screen's order.
        '${t.trailPointStart}$sep${bidiIsolateIfForeign('Olaya St', rtl: true)}'
            '$sep${t.trailAccuracy('8')}',
      ]);
    });

    testMapWidgets('endpoints get their own glyph and colour',
        (tester) async {
      repo.track = _mixedTrack();
      await pumpPage(tester);
      final leading = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => t.leading! as Icon)
          .toList();
      expect(leading.map((i) => i.icon), [
        Symbols.flag,
        Symbols.circle,
        Symbols.circle,
        Symbols.trip_origin,
      ]);
      final cs = Theme.of(tester.element(find.byType(ListTile).first))
          .colorScheme;
      expect(leading[1].color, cs.primary);
      expect(leading[0].size, greaterThan(leading[1].size!));
    });

    testMapWidgets('each fix opens in maps, named and full-size',
        (tester) async {
      final launched = mockUrlLauncher();
      repo.track = _mixedTrack();
      await pumpPage(tester);
      final t = l10n(english);
      final buttons = find.byTooltip(t.wfOpenInMaps);
      expect(buttons, findsNWidgets(4));
      final button = find
          .ancestor(of: buttons.first, matching: find.byType(IconButton))
          .first;
      expect(tester.getSize(button).height,
          greaterThanOrEqualTo(kMinInteractiveDimension));
      await tester.tap(buttons.first);
      await tester.pump();
      await tester.pump();
      // The newest fix is first.
      expect(launched, hasLength(1));
      expect(Uri.parse(launched.single).path, '24.73,46.7');
    });

    testMapWidgets('portrait stacks the map over the list', (tester) async {
      await pumpPage(tester);
      final map = tester.getRect(find.byType(AppMap));
      final list = tester.getRect(find.byType(CustomScrollView));
      expect(map.bottom, lessThanOrEqualTo(list.top + 0.5));
      expect(map.height / list.height, moreOrLessEquals(3 / 2, epsilon: 0.05));
    });

    testMapWidgets('landscape puts them side by side', (tester) async {
      await pumpPage(tester, surface: _landscapeEn);
      final map = tester.getRect(find.byType(AppMap));
      final list = tester.getRect(find.byType(CustomScrollView));
      expect(map.right, lessThanOrEqualTo(list.left + 0.5));
      expect(map.width / list.width, moreOrLessEquals(3 / 2, epsilon: 0.05));
      expectCleanLayout(tester);
    });

    testMapWidgets('the credit sits at the start, clear of the fit button',
        (tester) async {
      for (final (s, alignment) in [
        (phoneEn, Alignment.bottomLeft),
        (phoneAr, Alignment.bottomRight),
      ]) {
        await pumpPage(tester, surface: s);
        expect(tester.widget<AppMap>(find.byType(AppMap)).attributionAlignment,
            alignment);
      }
    });

    testMapWidgets('the fit button is named and refits the camera',
        (tester) async {
      await pumpPage(tester);
      final t = l10n(english);
      final fab = find.bySemanticsLabel(t.trailFitRoute);
      expect(fab, findsOneWidget);
      // The map opens fitted: flutter_map applies the fit after its first
      // frame, so read the controller one frame later.
      await tester.pump();
      final controller = tester.widget<AppMap>(find.byType(AppMap)).controller!;
      final fitted = controller.camera.zoom;
      expect(fitted, lessThan(AppConstants.mapZoomVisitFitMax));
      expect(fitted, isNot(AppConstants.mapZoomVisitDetail));

      // Pan and zoom away, then ask for the route back.
      controller.move(_far, 5);
      await tester.pump();
      expect(controller.camera.zoom, 5);
      await tester.tap(find.byType(MapFab));
      await tester.pump();
      expect(controller.camera.zoom, moreOrLessEquals(fitted, epsilon: 0.01));
    });

    testMapWidgets('without road matching there is no line toggle',
        (tester) async {
      await pumpPage(tester);
      expect(find.byType(RouteLineToggle), findsNothing);
    });

    testMapWidgets('the line toggle switches between roads and raw GPS',
        (tester) async {
      withMatching();
      await pumpPage(tester);
      await tester.pump();
      final t = l10n(english);
      RouteLineToggle toggle() =>
          tester.widget<RouteLineToggle>(find.byType(RouteLineToggle));
      expect(toggle().mode, RouteLineMode.roads);
      // The fake matcher finds no road: the raw line is said to be shown.
      expect(toggle().unmatched, isTrue);
      expect(find.text(t.routeLineUnmatched), findsOneWidget);

      await tester.tap(find.text(t.routeLineGps));
      await tester.pump();
      expect(toggle().mode, RouteLineMode.raw);
      expect(find.text(t.routeLineUnmatched), findsNothing);

      await tester.tap(find.text(t.routeLineRoads));
      await tester.pump();
      expect(toggle().mode, RouteLineMode.roads);
    });
  });

  group('uploads', () {
    testWidgets('nothing waiting: no upload action', (tester) async {
      withTracker();
      repo.track = const VisitTrack(visitId: 5);
      await pumpPage(tester, visit: _running);
      expect(find.byIcon(Symbols.cloud_upload), findsNothing);
    });

    testWidgets('fixes waiting: a badge, named, that uploads them',
        (tester) async {
      withTracker();
      tracker.pendingNotifier.value = 6;
      repo.track = const VisitTrack(visitId: 5);
      await pumpPage(tester, visit: _running);
      final t = l10n(english);
      expect(find.byIcon(Symbols.cloud_upload), findsOneWidget);
      expect(find.byTooltip(t.trailPendingUploads(6)), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      await tester.tap(find.byTooltip(t.trailPendingUploads(6)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tracker.flushCalls, 1);
      expect(find.text(t.trailUploadDone), findsOneWidget);
      expect(find.byIcon(Symbols.cloud_upload), findsNothing,
          reason: 'the badge goes once the buffer is empty');
    });

    testWidgets('fixes still stuck after the upload say so',
        (tester) async {
      withTracker();
      tracker.pendingNotifier.value = 6;
      tracker.pendingAfterFlush = 2;
      repo.track = const VisitTrack(visitId: 5);
      await pumpPage(tester, visit: _running, surface: phoneAr);
      final t = l10n(arabic);
      await tester.tap(find.byTooltip(t.trailPendingUploads(6)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(t.trailUploadStillPending(2)), findsOneWidget);
      expect(find.byTooltip(t.trailPendingUploads(2)), findsOneWidget);
    });
  });

  group('live refresh', () {
    testMapWidgets('a running visit polls, and the new fixes are listed',
        (tester) async {
      var fixes = 2;
      repo.onReadTrack = (_) async => trackOf(5, fixes);
      await pumpPage(tester, visit: _running);
      expect(find.byType(ListTile), findsNWidgets(2));

      fixes = 3;
      await tester.pump(AppConstants.trailLiveRefreshInterval);
      await tester.pump();
      expect(repo.readTrackCalls, 2);
      expect(find.byType(ListTile), findsNWidgets(3));
    });

    testWidgets('an empty running trail fills in when fixes arrive',
        (tester) async {
      var fixes = 0;
      repo.onReadTrack = (_) async => trackOf(5, fixes);
      await ignoringTileFailures(tester, () async {
        await pumpPage(tester, visit: _running);
        expect(find.byType(EmptyView), findsOneWidget);
        fixes = 2;
        await tester.pump(AppConstants.trailLiveRefreshInterval);
        await tester.pump();
        expect(find.byType(EmptyView), findsNothing);
        expect(find.byType(AppMap), findsOneWidget);
      });
    });

    testWidgets('a finished visit is read once', (tester) async {
      repo.track = const VisitTrack(visitId: 5);
      await pumpPage(tester);
      await tester.pump(AppConstants.trailLiveRefreshInterval * 3);
      expect(repo.readTrackCalls, 1);
    });

    testMapWidgets('an upload landing elsewhere refetches at once',
        (tester) async {
      withTracker();
      await pumpPage(tester);
      expect(repo.readTrackCalls, 1);
      tracker.revisionNotifier.value++;
      await tester.pump();
      expect(repo.readTrackCalls, 2);
    });

    testMapWidgets('a later poll leaves the camera where the user put it',
        (tester) async {
      var fixes = 3;
      repo.onReadTrack = (_) async => trackOf(5, fixes);
      await pumpPage(tester, visit: _running);
      final controller = tester.widget<AppMap>(find.byType(AppMap)).controller!;
      controller.move(_far, 6);
      await tester.pump();

      fixes = 5;
      await tester.pump(AppConstants.trailLiveRefreshInterval);
      await tester.pump();
      expect(repo.readTrackCalls, 2);
      // The fix count in the stats (the list itself is built lazily).
      expect(find.text(AppNumber.whole(5)), findsOneWidget);
      expect(controller.camera.zoom, 6);
      expect(controller.camera.center, _far);
    });
  });
}
