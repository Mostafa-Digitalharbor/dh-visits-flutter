import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/app_tool_button.dart';

import 'widget_harness.dart';

Widget _row(Surface s, {VoidCallback? onPressed, bool loading = false}) {
  final t = l10n(s.locale);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (label, icon) in [
        (t.wfActionReschedule, Icons.event_repeat),
        (t.wfActionTakePhoto, Icons.photo_camera_outlined),
        (t.wfActionAddAttachmentCount(128), Icons.attach_file),
        (t.wfActionCancel, Icons.block),
      ])
        Expanded(
          child: AppToolButton(
            label: label,
            icon: icon,
            loading: loading,
            destructive: icon == Icons.block,
            onPressed: onPressed ?? () {},
          ),
        ),
    ],
  );
}

Color? _iconColor(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon)).color;

void main() {
  setUpAll(initHarness);

  group('layout', () {
    testOnEverySurface(
      'four tools share one row',
      (s) => _row(s),
      verify: (tester, s) async {
        final tops = [
          for (final e in find.byType(AppToolButton).evaluate())
            tester.getRect(find.byWidget(e.widget)).top,
        ];
        expect(tops.toSet(), hasLength(1));
      },
    );

    testOnEverySurface('four spinning tools share one row',
        (s) => _row(s, loading: true));

    testWidgets('the touch target is at least 48dp', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: AppToolButton(label: 'X', icon: Icons.add, onPressed: () {}),
        ),
      );
      final size = tester.getSize(find.byType(InkWell));
      expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('a long label wraps to two lines, then ellipsizes',
        (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        SizedBox(
          width: 80,
          child: AppToolButton(
            label: LongText.arabicCompany,
            icon: Icons.add,
            onPressed: () {},
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expectCleanLayout(tester);
    });
  });

  group('behaviour', () {
    testWidgets('a tap fires once', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: AppToolButton(
            label: 'Photo',
            icon: Icons.photo_camera_outlined,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(AppToolButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('loading spins and ignores taps', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: AppToolButton(
            label: 'Photo',
            icon: Icons.photo_camera_outlined,
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      // The label stays, so the user knows what is running.
      expect(find.text('Photo'), findsOneWidget);
      await tester.tap(find.byType(AppToolButton));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('disabled is dimmed and ignores taps', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(
          child: AppToolButton(label: 'Photo', icon: Icons.add, onPressed: null),
        ),
      );
      final context = tester.element(find.byType(AppToolButton));
      expect(
        _iconColor(tester),
        Theme.of(context).colorScheme.onSurface.withValues(
              alpha: Alphas.disabled,
            ),
      );
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });

    testWidgets('colour: primary, or error when destructive', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: AppToolButton(label: 'A', icon: Icons.add, onPressed: () {}),
        ),
      );
      final scheme = Theme.of(tester.element(find.byType(Icon))).colorScheme;
      expect(_iconColor(tester), scheme.primary);

      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: AppToolButton(
            label: 'A',
            icon: Icons.block,
            destructive: true,
            onPressed: () {},
          ),
        ),
      );
      expect(_iconColor(tester), scheme.error);
    });

    testWidgets('named for tooltips and screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(
        tester,
        phoneAr,
        Center(
          child: AppToolButton(
            label: l10n(arabic).wfActionTakePhoto,
            icon: Icons.photo_camera_outlined,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byTooltip(l10n(arabic).wfActionTakePhoto), findsOneWidget);
      final node = tester.getSemantics(
        find.bySemanticsLabel(l10n(arabic).wfActionTakePhoto),
      );
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });
}
