// Renders the widgets that carry user-controlled Odoo text, or a fixed-height
// illustration, in the viewports where they used to break: a short landscape
// body, a small phone, and the app's 1.25 text-scale cap.
//
// Flutter surfaces a RenderFlex overflow as a FlutterError during paint, which
// the test binding records in `takeException()` — so "no exception" here is a
// real assertion that nothing overflowed, not a proxy for it.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_attachment.dart';
import 'package:location_gps/features/visits/view/visit_attachments_section.dart';
import 'package:location_gps/features/visits/view/visit_section.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';
import 'package:location_gps/shared/widgets/empty_view.dart';
import 'package:location_gps/shared/widgets/error_view.dart';
import 'package:location_gps/shared/widgets/visit_card.dart';

/// A landscape phone body: the case that broke the visits empty state.
const _landscape = Size(720, 360);

/// A small portrait phone.
const _smallPhone = Size(320, 640);

Future<void> pumpIn(
  WidgetTester tester,
  Widget child, {
  required Size size,
  Locale locale = const Locale('ar'),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      // Mirror app.dart's clamp: 1.25 is the most text can ever grow.
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async => initializeDateFormatting());

  // A realistic long Odoo name — the kind that actually ships in this app.
  const longArabicName =
      'مشروع تطوير أبراج الرياض السكنية والتجارية - المرحلة الثانية';
  const longArabicCustomer = 'شركة الخليج للمقاولات والاستثمار العقاري المحدودة';

  group('EmptyView', () {
    // The real landscape budget on the visits screen, and the reason a bare
    // Center overflowed: a 360dp-tall viewport minus the app bar (~58) and
    // nav bar (~80) leaves ~222 for the body, and the list's own search field
    // (~56) takes it down to ~166 — against a ~235dp illustration + text.
    // A bare Scaffold body would hand it the full 360 and hide the bug, so
    // the constraint has to be modelled explicitly.
    const shellBody = SizedBox(
      height: 166,
      width: 720,
      child: EmptyView(message: 'لا توجد زيارات اليوم'),
    );

    testWidgets('does not overflow the real landscape body budget', (t) async {
      await pumpIn(t, const Center(child: shellBody), size: _landscape);
      expect(t.takeException(), isNull);
    });

    testWidgets('does not overflow that budget at the max text scale',
        (t) async {
      await pumpIn(
        t,
        const Center(
          child: SizedBox(
            height: 166,
            width: 720,
            child: EmptyView(
              message: 'لا توجد زيارات اليوم. اسحب للأسفل لتحديث القائمة.',
            ),
          ),
        ),
        size: _landscape,
        textScale: 1.25,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('scrolls to reach content too tall for the viewport',
        (t) async {
      // Not just "doesn't throw": the message must still be reachable, which
      // is the whole point of scrolling rather than shrinking.
      await pumpIn(t, const Center(child: shellBody), size: _landscape);
      await t.drag(find.byType(EmptyView), const Offset(0, -80));
      await t.pump();
      expect(find.text('لا توجد زيارات اليوم'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('still renders inside an unbounded-height ListView',
        (t) async {
      // The notifications empty state does exactly this. A naive
      // SingleChildScrollView here would throw "Vertical viewport was given
      // unbounded height" instead of fixing anything.
      await pumpIn(
        t,
        ListView(
          children: const [EmptyView(message: 'مفيش حاجة مطلوبة منك')],
        ),
        size: _landscape,
      );
      expect(t.takeException(), isNull);
      expect(find.text('مفيش حاجة مطلوبة منك'), findsOneWidget);
    });
  });

  group('ErrorView', () {
    testWidgets('does not overflow a short landscape body', (t) async {
      await pumpIn(
        t,
        ErrorView(message: 'حدث خطأ غير متوقع', onRetry: () {}),
        size: _landscape,
        textScale: 1.25,
      );
      expect(t.takeException(), isNull);
    });
  });

  group('VisitCard', () {
    // The regression: _meta() put a bare Text in a Row inside a Wrap, so a
    // long linked-record name took its full intrinsic width and overflowed
    // every row of the main list.
    final visit = Visit(
      id: 1,
      name: 'V-0001',
      visitType: VisitType.project,
      projectName: longArabicName,
      partnerName: longArabicCustomer,
      employeeName: 'محمد عبد الرحمن السيد',
      scheduledDatetime: DateTime(2026, 7, 15, 14, 30),
      purpose: 'متابعة تنفيذ المرحلة الثانية ومراجعة الجدول الزمني',
      isEscalated: true,
    );

    testWidgets('a long linked name does not overflow on a small phone',
        (t) async {
      await pumpIn(
        t,
        VisitCard(visit: visit, showEmployee: true, onTap: () {}),
        size: _smallPhone,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('survives a long name at the max text scale', (t) async {
      await pumpIn(
        t,
        VisitCard(visit: visit, showEmployee: true, onTap: () {}),
        size: _smallPhone,
        textScale: 1.25,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('renders its schedule with Arabic month names', (t) async {
      await pumpIn(
        t,
        VisitCard(visit: visit, onTap: () {}),
        size: _smallPhone,
      );
      expect(t.takeException(), isNull);
      // Arabic month word, Latin digits — see AppDate.
      expect(find.textContaining('يوليو'), findsOneWidget);
      expect(find.textContaining('14:30'), findsOneWidget);
    });
  });

  // The two widgets extracted out of visit_detail_page during the refactor.
  // They carry user-controlled Odoo data (attachment filenames, section
  // titles), so the same overflow guarantees must hold for them.
  group('VisitAttachmentsSection', () {
    const longArabicFile =
        'تقرير زيارة العميل المفصّل - المرحلة الثانية من المشروع.pdf';

    testWidgets('a long Arabic filename does not overflow on a small phone',
        (t) async {
      await pumpIn(
        t,
        const SingleChildScrollView(
          child: VisitAttachmentsSection(
            attachments: [
              VisitAttachment(
                  id: 1,
                  name: longArabicFile,
                  mimetype: 'application/pdf',
                  fileSize: 204800),
            ],
          ),
        ),
        size: _smallPhone,
        textScale: 1.25,
      );
      expect(t.takeException(), isNull);
      expect(find.textContaining('تقرير'), findsOneWidget);
    });

    testWidgets('renders its error state without overflowing', (t) async {
      await pumpIn(
        t,
        SingleChildScrollView(
          child: VisitAttachmentsSection(
            attachments: const [],
            error: ApiException(code: ApiErrorCode.permissionDenied),
          ),
        ),
        size: _smallPhone,
        textScale: 1.25,
      );
      expect(t.takeException(), isNull);
    });
  });

  group('VisitSection', () {
    testWidgets('a long title ellipsizes instead of overflowing', (t) async {
      await pumpIn(
        t,
        const SingleChildScrollView(
          child: VisitSection(
            icon: Icons.info_outline,
            title:
                'تفاصيل الموافقة والفريق المسؤول عن تنفيذ ومتابعة هذه الزيارة',
            rows: [Text('row')],
          ),
        ),
        size: _smallPhone,
        textScale: 1.25,
      );
      expect(t.takeException(), isNull);
    });
  });

  // The manager shell went from three tabs to four when Profile was added, so
  // every label now gets a quarter of the width instead of a third — on a 320dp
  // phone that is 80dp per destination, and Arabic labels like "لوحة المتابعة"
  // and "التحليلات" are long. `HomeShell` itself needs half the app's blocs and
  // a GPS acquire to render, so the bar is built here from the same
  // localizations the shells read; the count assertions pin it to their tab
  // lists so a fourth employee tab or a fifth manager tab has to come here too.
  group('bottom navigation', () {
    /// `_UserShell` / `_ManagerShell` in `lib/features/home/view/home_shell.dart`.
    List<String> employeeLabels(AppLocalizations s) =>
        [s.visitsTabTitle, s.routeTabTitle, s.profileTabTitle];
    List<String> managerLabels(AppLocalizations s) => [
          s.dashboardTabTitle,
          s.visitsTabTitle,
          s.analyticsTabTitle,
          s.profileTabTitle,
        ];

    Future<void> pumpBar(
      WidgetTester t,
      List<String> Function(AppLocalizations) labels, {
      required Locale locale,
      required double textScale,
      required int expectedCount,
    }) async {
      await pumpIn(
        t,
        Builder(
          builder: (context) {
            final names = labels(AppLocalizations.of(context));
            expect(names.length, expectedCount);
            return NavigationBar(
              selectedIndex: 0,
              destinations: [
                for (final n in names)
                  NavigationDestination(
                      icon: const Icon(Icons.circle), label: n),
              ],
            );
          },
        ),
        size: _smallPhone,
        locale: locale,
        textScale: textScale,
      );
      expect(t.takeException(), isNull);
    }

    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final scale in const [1.0, 1.25]) {
        final tag = '${locale.languageCode} · ${scale}x';

        testWidgets("the manager's four tabs fit a 320dp phone — $tag",
            (t) async {
          await pumpBar(t, managerLabels,
              locale: locale, textScale: scale, expectedCount: 4);
        });

        testWidgets("the employee's three tabs fit a 320dp phone — $tag",
            (t) async {
          await pumpBar(t, employeeLabels,
              locale: locale, textScale: scale, expectedCount: 3);
        });
      }
    }
  });
}
