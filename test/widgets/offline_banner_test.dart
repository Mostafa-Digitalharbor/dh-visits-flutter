import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/di/service_locator.dart';
import 'package:location_gps/core/network/connectivity_status.dart';
import 'package:location_gps/core/network/pending_actions_queue.dart';
import 'package:location_gps/shared/widgets/offline_banner.dart';
import 'package:location_gps/shared/widgets/status_banner.dart';

import 'widget_harness.dart';

/// Only the counter the banner listens to; anything else would be a bug.
class _FakeQueue implements PendingActionsQueue {
  @override
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

late ConnectivityStatus _connectivity;
late _FakeQueue _queue;

/// Sets the global state the banner reads, then returns it under an app-bar
/// sized strip, the way the home shell stacks it.
Widget _banner({required bool online, int pending = 0}) {
  if (online) {
    _connectivity.markOnline();
  } else {
    _connectivity.markOffline();
  }
  _queue.pendingCount.value = pending;
  return const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(key: Key('appbar'), height: 56),
      OfflineBanner(),
      Expanded(child: Placeholder(key: Key('body'))),
    ],
  );
}

void main() {
  setUpAll(initHarness);

  setUp(() {
    // No probe: nothing periodic runs while the app is "offline".
    _connectivity = ConnectivityStatus();
    _queue = _FakeQueue();
    sl
      ..registerSingleton<ConnectivityStatus>(_connectivity)
      ..registerSingleton<PendingActionsQueue>(_queue);
  });

  tearDown(() async {
    await sl.reset();
    _connectivity.dispose();
    _queue.pendingCount.dispose();
  });

  group('OfflineBanner layout', () {
    testOnEverySurface(
      'offline with a large queue fits',
      (s) => _banner(online: false, pending: 1234),
      verify: (tester, s) async {
        expect(find.text(l10n(s.locale).offlineWithQueue(1234)), findsOne);
      },
    );

    testOnEverySurface(
      'offline with nothing queued (the longest sentence) fits',
      (s) => _banner(online: false),
      verify: (tester, s) async {
        expect(find.text(l10n(s.locale).offlineNoQueue), findsOne);
      },
    );

    testOnEverySurface(
      'syncing fits',
      (s) => _banner(online: true, pending: 3),
    );
  });

  group('OfflineBanner states', () {
    testWidgets('online with nothing queued takes no space at all',
        (tester) async {
      await pumpSurface(tester, phoneEn, _banner(online: true));
      expect(find.byType(StatusBanner), findsNothing);
      expect(tester.getSize(find.byType(OfflineBanner)), const Size(390, 0));
      // No shift: the body starts right under the app bar.
      expect(
        tester.getTopLeft(find.byKey(const Key('body'))).dy,
        tester.getBottomLeft(find.byKey(const Key('appbar'))).dy,
      );
    });

    for (final surface in [phoneEn, surfaces[2]]) {
      testWidgets('online with a queue is an amber "syncing" strip — $surface',
          (tester) async {
        await pumpSurface(tester, surface, _banner(online: true, pending: 2));
        final banner = tester.widget<StatusBanner>(find.byType(StatusBanner));
        final context = tester.element(find.byType(StatusBanner));
        expect(banner.color, context.x.warning);
        expect(banner.icon, Icons.sync_rounded);
        expect(banner.message, l10n(surface.locale).offlineSyncing(2));
        expect(banner.action, isNull);
      });

      testWidgets('offline is a red strip — $surface', (tester) async {
        await pumpSurface(tester, surface, _banner(online: false));
        final banner = tester.widget<StatusBanner>(find.byType(StatusBanner));
        final context = tester.element(find.byType(StatusBanner));
        expect(banner.color, Theme.of(context).colorScheme.error);
        expect(banner.icon, Icons.cloud_off_rounded);
        expect(banner.message, l10n(surface.locale).offlineNoQueue);
      });

      testWidgets('offline with a queue says how much is waiting — $surface',
          (tester) async {
        await pumpSurface(tester, surface, _banner(online: false, pending: 4));
        final banner = tester.widget<StatusBanner>(find.byType(StatusBanner));
        final context = tester.element(find.byType(StatusBanner));
        expect(banner.color, Theme.of(context).colorScheme.error);
        expect(banner.icon, Icons.cloud_off_rounded);
        expect(banner.message, l10n(surface.locale).offlineWithQueue(4));
      });
    }

    testWidgets('follows connectivity and the queue live, without a rebuild',
        (tester) async {
      final t = l10n(english);
      await pumpSurface(tester, phoneEn, _banner(online: true));
      expect(find.byType(StatusBanner), findsNothing);

      _connectivity.markOffline();
      await tester.pump();
      expect(find.text(t.offlineNoQueue), findsOneWidget);

      _queue.pendingCount.value = 1;
      await tester.pump();
      expect(find.text(t.offlineWithQueue(1)), findsOneWidget);

      _connectivity.markOnline();
      await tester.pump();
      expect(find.text(t.offlineSyncing(1)), findsOneWidget);

      _queue.pendingCount.value = 0;
      await tester.pump();
      expect(find.byType(StatusBanner), findsNothing);
      expect(tester.getSize(find.byType(OfflineBanner)).height, 0);
    });
  });

  group('OfflineBanner plurals', () {
    for (final (n, text) in const [
      (1, 'Offline — 1 action waiting to sync'),
      (2, 'Offline — 2 actions waiting to sync'),
      (25, 'Offline — 25 actions waiting to sync'),
    ]) {
      testWidgets('en offline, $n queued', (tester) async {
        await pumpSurface(tester, phoneEn, _banner(online: false, pending: n));
        expect(find.text(text), findsOneWidget);
      });
    }

    for (final (n, text) in const [
      (1, 'Syncing 1 pending action…'),
      (7, 'Syncing 7 pending actions…'),
    ]) {
      testWidgets('en syncing, $n queued', (tester) async {
        await pumpSurface(tester, phoneEn, _banner(online: true, pending: n));
        expect(find.text(text), findsOneWidget);
      });
    }

    // Arabic has distinct forms for 1, 2, 3–10, 11–99 and 100+.
    for (final (n, offline, syncing) in const [
      (1, 'غير متصل — إجراء واحد بانتظار المزامنة',
          'جارٍ مزامنة إجراء واحد معلّق…'),
      (2, 'غير متصل — إجراءان بانتظار المزامنة', 'جارٍ مزامنة إجراءين معلّقين…'),
      (3, 'غير متصل — 3 إجراءات بانتظار المزامنة',
          'جارٍ مزامنة 3 إجراءات معلّقة…'),
      (11, 'غير متصل — 11 إجراءً بانتظار المزامنة',
          'جارٍ مزامنة 11 إجراءً معلّقًا…'),
      (100, 'غير متصل — 100 إجراء بانتظار المزامنة',
          'جارٍ مزامنة 100 إجراء معلّق…'),
    ]) {
      testWidgets('ar, $n queued', (tester) async {
        await pumpSurface(tester, phoneAr, _banner(online: false, pending: n));
        expect(find.text(offline), findsOneWidget);
        expect(offline, l10n(arabic).offlineWithQueue(n));

        _connectivity.markOnline();
        await tester.pump();
        expect(find.text(syncing), findsOneWidget);
        expect(syncing, l10n(arabic).offlineSyncing(n));
      });
    }
  });
}
