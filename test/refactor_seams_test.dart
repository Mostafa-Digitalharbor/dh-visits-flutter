// Cover for the seams introduced when list filtering, tab construction and the
// mock-GPS note text were pulled out of the widgets that used to inline them.
//
// Each of these is a place where the refactor could silently change behaviour:
// a filter that stops matching, a tab that builds eagerly after all, or an
// audit note that loses the marker managers search on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/features/visits/bloc/visits_list_bloc.dart';
import 'package:location_gps/features/visits/data/mock_location_note.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/shared/widgets/lazy_indexed_stack.dart';

Visit _v(int id, {String? partner, String? name, String? purpose, VisitState? state}) =>
    Visit(
      id: id,
      partnerName: partner,
      name: name,
      purpose: purpose,
      state: state ?? VisitState.approved,
    );

void main() {
  group('VisitsListState.visible', () {
    final items = [
      _v(1, partner: 'Acme Trading', name: 'VIS/2026/00001', purpose: 'Demo'),
      _v(2, partner: 'Globex', name: 'VIS/2026/00002', purpose: 'Contract review'),
      _v(3, partner: 'Initech', name: 'VIS/2026/00003', state: VisitState.done),
    ];

    test('no query and no filter returns the list itself, uncopied', () {
      final state = VisitsListState(items: items);
      // Identity, not just equality: the common case must not allocate.
      expect(identical(state.visible, items), isTrue);
    });

    test('matches customer, reference and purpose, case-insensitively', () {
      expect(VisitsListState(items: items, searchQuery: 'acme').visible,
          hasLength(1));
      expect(VisitsListState(items: items, searchQuery: '00002').visible.single.id, 2);
      expect(VisitsListState(items: items, searchQuery: 'CONTRACT').visible.single.id, 2);
    });

    test('surrounding whitespace does not defeat a search', () {
      expect(VisitsListState(items: items, searchQuery: '  globex ').visible,
          hasLength(1));
    });

    test('a state filter and a query compose', () {
      final state = VisitsListState(
        items: items,
        searchQuery: 'vis/2026',
        stateFilter: VisitState.done,
      );
      expect(state.visible.single.id, 3);
    });

    test('a non-matching query yields empty rather than everything', () {
      expect(VisitsListState(items: items, searchQuery: 'zzz').visible, isEmpty);
    });

    test('the result is cached, so repeat reads do not re-filter', () {
      final state = VisitsListState(items: items, searchQuery: 'acme');
      expect(identical(state.visible, state.visible), isTrue);
    });

    test('initial hands back a fresh instance each time', () {
      // A reset must not return an instance whose cached `visible` was already
      // forced against a previous user's rows.
      expect(identical(VisitsListState.initial, VisitsListState.initial), isFalse);
      expect(VisitsListState.initial.items, isEmpty);
      expect(VisitsListState.initial.status, VisitsListStatus.initial);
    });
  });

  group('LazyIndexedStack', () {
    /// Records every build so a test can assert a tab was never constructed.
    Widget probe(String label, List<String> log) => Builder(
          builder: (_) {
            log.add(label);
            return Text(label, textDirection: TextDirection.ltr);
          },
        );

    testWidgets('builds only the selected child on first frame', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LazyIndexedStack(
          index: 0,
          children: [probe('a', log), probe('b', log), probe('c', log)],
        ),
      ));
      expect(log, ['a']);
    });

    testWidgets('builds a child once its tab is opened, and keeps it alive',
        (tester) async {
      final log = <String>[];
      Widget shell(int index) => Directionality(
            textDirection: TextDirection.ltr,
            child: LazyIndexedStack(
              index: index,
              children: [probe('a', log), probe('b', log), probe('c', log)],
            ),
          );

      await tester.pumpWidget(shell(0));
      await tester.pumpWidget(shell(2));
      expect(log, containsAllInOrder(['a', 'c']));
      expect(log, isNot(contains('b')));

      // Going back must not tear 'c' down — that is the whole reason this is a
      // stack and not a conditional build.
      await tester.pumpWidget(shell(0));
      expect(find.text('c', skipOffstage: false), findsOneWidget);
    });
  });

  group('MockLocationNote', () {
    test('both bodies carry the searchable marker', () {
      // Detection and the manager's Odoo message search both key off this
      // token, never the prose — losing it from either body makes a recorded
      // spoof invisible.
      final note = MockLocationNote.build(
        phase: SpoofPhase.start,
        latitude: 30.0444,
        longitude: 31.2357,
      );
      expect(note.plain, contains(kMockLocationMarker));
      expect(note.html, contains(kMockLocationMarker));
    });

    test('is bilingual in both bodies', () {
      // The note is read by a manager who may not share the spoofer's device
      // language, so English and Arabic always both appear.
      final note = MockLocationNote.build(phase: SpoofPhase.end);
      for (final body in [note.plain, note.html]) {
        expect(body, contains('Mock location detected'));
        expect(body, contains('تم رصد موقع وهمي'));
      }
    });

    test('names the phase it was raised at', () {
      final start = MockLocationNote.build(phase: SpoofPhase.start);
      final end = MockLocationNote.build(phase: SpoofPhase.end);
      expect(start.plain, contains('check-in'));
      expect(end.plain, contains('check-out'));
      expect(start.plain, isNot(contains('check-out')));
    });

    test('the plain body is self-contained — it is what survives', () {
      // The HTML rewrite is best-effort; if it never lands the plain post is
      // the permanent record, so it must state the verdict, the reason and the
      // coordinates on its own.
      final note = MockLocationNote.build(
        phase: SpoofPhase.start,
        latitude: 30.0444,
        longitude: 31.2357,
        location: 'Cairo Festival City',
      );
      expect(note.plain, contains('30.04440, 31.23570'));
      expect(note.plain, contains('Cairo Festival City'));
      expect(note.plain, contains('manual review'));
      // No markup — Odoo escapes it on a plain post, so tags would be shown raw.
      expect(note.plain, isNot(contains('<')));
    });

    test('a fix with no coordinates says so in both languages', () {
      final note = MockLocationNote.build(phase: SpoofPhase.start);
      expect(note.plain, contains('unavailable / غير متاح'));
    });

    test('the location line is omitted entirely when there is none', () {
      final note = MockLocationNote.build(phase: SpoofPhase.start);
      expect(note.html, isNot(contains('Reported location')));
    });
  });
}
