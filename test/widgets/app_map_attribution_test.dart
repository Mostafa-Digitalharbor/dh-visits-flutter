import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/shared/widgets/app_map_attribution.dart';

import 'widget_harness.dart';

const _host = Key('map-host');
const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

/// A map-sized box the badge pins itself into.
Widget _inMap(Widget badge) => Center(
  child: SizedBox(
    key: _host,
    width: 300,
    height: 200,
    child: ColoredBox(color: const Color(0xFFE5E5E5), child: badge),
  ),
);

Finder get _label => find.text(AppConstants.osmAttribution);

Finder get _badge => find.descendant(
  of: find.byType(AppMapAttribution),
  matching: find.byType(DecoratedBox),
);

/// Records the launch requests; [fail] makes the platform refuse them.
List<MethodCall> _mockLauncher(WidgetTester tester, {bool fail = false}) {
  final calls = <MethodCall>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_launcher, (call) async {
    calls.add(call);
    if (fail) throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
    return true;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_launcher, null));
  return calls;
}

void main() {
  setUpAll(initHarness);

  group('AppMapAttribution layout', () {
    for (final corner in [
      Alignment.bottomRight,
      Alignment.bottomLeft,
      Alignment.topLeft,
    ]) {
      testOnEverySurface(
        'the badge fits a small map at $corner',
        (s) => _inMap(AppMapAttribution(alignment: corner)),
        verify: (tester, s) async {
          expect(_label, findsOneWidget);
          final host = tester.getRect(find.byKey(_host));
          final badge = tester.getRect(_badge);
          expect(host.contains(badge.topLeft), isTrue);
          expect(host.contains(badge.bottomRight), isTrue);
          // A caption, not a banner — even at the largest text scale.
          expect(badge.height, lessThan(20));
        },
      );
    }
  });

  group('AppMapAttribution behaviour', () {
    testWidgets('shows the licence credit, identical in every language', (
      tester,
    ) async {
      for (final s in [phoneEn, phoneAr]) {
        await pumpSurface(tester, s, _inMap(const AppMapAttribution()));
        expect(_label, findsOneWidget, reason: '$s');
        expect(AppConstants.osmAttribution, '© OpenStreetMap');
      }
    });

    testWidgets('ignores the system text scale', (tester) async {
      Future<Size> labelAt(double scale) async {
        await pumpSurface(
          tester,
          Surface(
            'scale $scale',
            size: const Size(390, 844),
            locale: english,
            textScale: scale,
          ),
          _inMap(const AppMapAttribution()),
        );
        return tester.getSize(_badge);
      }

      final base = await labelAt(1);
      expect(await labelAt(Responsive.maxTextScale), base);
      expect(await labelAt(3), base);
    });

    testWidgets('sits bottom-right by default, inset by 4dp', (tester) async {
      await pumpSurface(tester, phoneEn, _inMap(const AppMapAttribution()));
      final host = tester.getRect(find.byKey(_host));
      final badge = tester.getRect(_badge);
      expect(host.right - badge.right, Insets.x1);
      expect(host.bottom - badge.bottom, Insets.x1);
    });

    testWidgets('bottomLeft pins it to the other corner', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _inMap(const AppMapAttribution(alignment: Alignment.bottomLeft)),
      );
      final host = tester.getRect(find.byKey(_host));
      final badge = tester.getRect(_badge);
      expect(badge.left - host.left, Insets.x1);
      expect(host.bottom - badge.bottom, Insets.x1);
    });

    testWidgets('the corner is physical: Arabic does not mirror it', (
      tester,
    ) async {
      // Callers pick the corner per direction themselves (the visit map and
      // the trail map pass bottomRight in RTL), so the badge must not flip it
      // a second time.
      Future<Rect> badgeIn(Surface s) async {
        await pumpSurface(
          tester,
          s,
          _inMap(const AppMapAttribution(alignment: Alignment.bottomLeft)),
        );
        return tester.getRect(_badge);
      }

      expect(await badgeIn(phoneAr), await badgeIn(phoneEn));
    });

    testWidgets('tapping opens the OSM copyright page once, externally', (
      tester,
    ) async {
      final calls = _mockLauncher(tester);
      await pumpSurface(tester, phoneEn, _inMap(const AppMapAttribution()));
      await tester.tap(_label);
      await tester.pump();
      expect(calls, hasLength(1));
      final args = calls.single.arguments as Map;
      expect(calls.single.method, 'launch');
      expect(args['url'], AppConstants.osmCopyrightUrl);
      expect(args['useWebView'], isFalse);
    });

    testWidgets('a refused launch is swallowed', (tester) async {
      final calls = _mockLauncher(tester, fail: true);
      await pumpSurface(tester, phoneEn, _inMap(const AppMapAttribution()));
      await tester.tap(_label);
      await tester.pump();
      expect(calls, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('no browser plugin at all is swallowed too', (tester) async {
      // No mock handler: the channel throws MissingPluginException.
      await pumpSurface(tester, phoneEn, _inMap(const AppMapAttribution()));
      await tester.tap(_label);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('only the badge itself is a link, not the map around it', (
      tester,
    ) async {
      // The hit area is deliberately the caption's own box (well under 48dp):
      // a padded target would swallow pans and taps meant for the map.
      final calls = _mockLauncher(tester);
      await pumpSurface(tester, phoneEn, _inMap(const AppMapAttribution()));
      final badge = tester.getRect(_badge);
      await tester.tapAt(badge.topLeft - const Offset(12, 12));
      await tester.tapAt(tester.getCenter(find.byKey(_host)));
      await tester.pump();
      expect(calls, isEmpty);
    });

    testWidgets('exposes the credit as a tappable label', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSurface(tester, phoneEn, _inMap(const AppMapAttribution()));
      expect(
        tester.getSemantics(_label),
        containsSemantics(
          label: AppConstants.osmAttribution,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('AppMapAttribution theming', () {
    Future<(Color?, Color?, double?)> colours(
      WidgetTester tester,
      Surface s,
    ) async {
      await pumpSurface(tester, s, _inMap(const AppMapAttribution()));
      final text = tester.widget<Text>(_label);
      final box =
          tester.widget<DecoratedBox>(_badge).decoration as BoxDecoration;
      return (text.style?.color, box.color, text.style?.fontSize);
    }

    testWidgets('light mode: dark text on a translucent white badge', (
      tester,
    ) async {
      final (fg, bg, size) = await colours(tester, phoneEn);
      expect(fg, AppColors.onMapLight);
      expect(bg, AppColors.onMap.withValues(alpha: Alphas.mapBadge));
      expect(size, FontSz.micro);
    });

    testWidgets('dark mode: white text on a translucent black badge', (
      tester,
    ) async {
      final (fg, bg, size) = await colours(tester, surfaces[2]);
      expect(fg, AppColors.onMap);
      expect(bg, Colors.black.withValues(alpha: Alphas.mapBadge));
      expect(size, FontSz.micro);
    });
  });
}
