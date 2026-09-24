import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/view/visit_hero_header.dart';
import 'package:location_gps/features/visits/view/visit_labels.dart';
import 'package:location_gps/shared/widgets/widgets.dart';

import '../../widgets/widget_harness.dart';

Visit _visit({
  int id = 42,
  String? name = 'VIS/2026/00042',
  String? partner = LongText.arabicCompany,
  VisitType type = VisitType.project,
  String? project = 'مشروع تطوير الواجهة البحرية — المرحلة الثانية والثالثة',
  String? opportunity,
  VisitState state = VisitState.waitingParticipantManagerApproval,
}) =>
    Visit(
      id: id,
      name: name,
      partnerName: partner,
      visitType: type,
      projectName: project,
      opportunityName: opportunity,
      state: state,
    );

void main() {
  setUpAll(initHarness);

  group('VisitHeroHeader layout', () {
    testOnEverySurface(
      'every state under the longest title, reference and linked record',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final state in VisitState.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VisitHeroHeader(
                  visit: _visit(
                    state: state,
                    partner: '${LongText.of(s)} ${LongText.of(s)}',
                  ),
                ),
              ),
          ],
        ),
      ),
      scrollable: true,
      verify: (tester, s) async {
        expect(find.byType(VisitHeroHeader),
            findsNWidgets(VisitState.values.length));
        final title = tester.widget<Text>(
            find.text('${LongText.of(s)} ${LongText.of(s)}').first);
        expect(title.maxLines, 2);
        expect(title.overflow, TextOverflow.ellipsis);
      },
    );

    testOnEverySurface(
      'a bare visit: no customer, no reference, unknown type',
      (s) => VisitHeroHeader(
        visit: _visit(
          name: null,
          partner: null,
          type: VisitType.unknown,
          project: null,
          state: VisitState.unknown,
        ),
      ),
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.text(t.visitFallbackTitle(42)), findsOneWidget);
        expect(find.text(t.wfStateUnknown), findsOneWidget);
      },
    );
  });

  group('VisitHeroHeader behaviour', () {
    testWidgets('the customer leads, with the reference under it',
        (tester) async {
      await pumpSurface(tester, phoneEn, VisitHeroHeader(visit: _visit()));
      final title = tester.getRect(find.text(LongText.arabicCompany));
      final reference = tester.getRect(find.text('VIS/2026/00042'));
      expect(reference.top, greaterThan(title.top));
      final ref = tester.widget<Text>(find.text('VIS/2026/00042'));
      expect(ref.maxLines, 1);
      expect(ref.style?.color, AppColors.onMap.withValues(alpha: Alphas.subdued));
    });

    testWidgets('without a customer the reference is the title, shown once',
        (tester) async {
      await pumpSurface(
          tester, phoneEn, VisitHeroHeader(visit: _visit(partner: null)));
      expect(find.text('VIS/2026/00042'), findsOneWidget);
      final title = tester.widget<Text>(find.text('VIS/2026/00042'));
      expect(title.maxLines, 2, reason: 'it is the title line');
    });

    testWidgets('the type line joins the type and the linked project',
        (tester) async {
      await pumpSurface(tester, phoneAr, VisitHeroHeader(visit: _visit()));
      final t = l10n(arabic);
      final line = '${t.wfTypeProject}${t.commonListSeparator}'
          'مشروع تطوير الواجهة البحرية — المرحلة الثانية والثالثة';
      final text = tester.widget<Text>(find.text(line));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('an opportunity shows its name and the trophy badge',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        VisitHeroHeader(
          visit: _visit(
            type: VisitType.opportunity,
            project: 'ignored project',
            opportunity: 'Tower B fit-out',
          ),
        ),
      );
      final t = l10n(english);
      expect(
        find.text('${t.wfTypeOpportunity}${t.commonListSeparator}'
            'Tower B fit-out'),
        findsOneWidget,
      );
      expect(find.textContaining('ignored project'), findsNothing);
      final badge = tester.widget<IconBadge>(find.byType(IconBadge));
      expect(badge.icon, Icons.emoji_events_outlined);
      expect(badge.iconColor, AppColors.cyan400);
    });

    testWidgets('a project shows the storefront badge', (tester) async {
      await pumpSurface(tester, phoneEn, VisitHeroHeader(visit: _visit()));
      expect(tester.widget<IconBadge>(find.byType(IconBadge)).icon,
          Icons.storefront_outlined);
    });

    testWidgets('an unknown type with no record leaves an empty type line',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        VisitHeroHeader(
            visit: _visit(type: VisitType.unknown, project: 'x')),
      );
      // The linked record is only read for a known type.
      expect(find.text(''), findsOneWidget);
      expectCleanLayout(tester);
    });

    double contrast(Color x, Color y) {
      final lx = x.computeLuminance();
      final ly = y.computeLuminance();
      return (math.max(lx, ly) + 0.05) / (math.min(lx, ly) + 0.05);
    }

    for (final s in const [phoneEn, phoneAr]) {
      testWidgets('every state badge reads on the dark hero — ${s.name}',
          (tester) async {
        for (final state in VisitState.values) {
          await pumpSurface(
            tester,
            s,
            VisitHeroHeader(visit: _visit(state: state)),
          );
          final context = tester.element(find.byType(VisitHeroHeader));
          final pill = tester.widget<TonePill>(find.byType(TonePill));
          expect(pill.label, visitStateLabel(context, state));
          final base = visitStateColor(context, state);
          expect(pill.color,
              VisitHeroHeader.legibleOn(base, AppColors.navy700));
          // WCAG AA against the gradient's lighter end.
          expect(contrast(pill.color, AppColors.navy700),
              greaterThanOrEqualTo(4.5),
              reason: state.name);
          expect(pill.borderAlpha, isNotNull,
              reason: 'an outline keeps it off the gradient');
        }
      });
    }

    testWidgets('the badge sits at the end of its row in both languages',
        (tester) async {
      for (final s in const [phoneEn, phoneAr]) {
        await pumpSurface(tester, s, VisitHeroHeader(visit: _visit()));
        final badge = tester.getCenter(find.byType(TonePill)).dx;
        final icon = tester.getCenter(find.byType(IconBadge)).dx;
        expect(badge > icon, s == phoneEn, reason: s.name);
      }
    });

    testWidgets('the brand gradient and glow come from the theme',
        (tester) async {
      await pumpSurface(tester, phoneEn, VisitHeroHeader(visit: _visit()));
      final context = tester.element(find.byType(VisitHeroHeader));
      final box = tester.widget<Container>(find
          .descendant(
              of: find.byType(VisitHeroHeader),
              matching: find.byType(Container))
          .first);
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.boxShadow, context.x.glowBrand);
      expect((decoration.gradient! as LinearGradient).colors,
          [AppColors.navy700, AppColors.navy900]);
      expect(
        tester.widget<Text>(find.text(LongText.arabicCompany)).style?.color,
        AppColors.onMap,
      );
    });
  });
}
