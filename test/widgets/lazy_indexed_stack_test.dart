// Extends test/refactor_seams_test.dart, which already covers "only the
// selected child is built on the first frame" and "an opened tab is built and
// is still in the tree after switching back". This file covers what that
// does not: state survival, the build log across many switches, list
// resizing, offstage behaviour and the layout matrix.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/shared/widgets/lazy_indexed_stack.dart';

import 'widget_harness.dart';

/// A tab that counts its taps and records when its State is created.
class _Tab extends StatefulWidget {
  final String label;
  final List<String> created;
  const _Tab(this.label, this.created, {super.key});

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  int taps = 0;
  bool ticking = true;

  @override
  void initState() {
    super.initState();
    widget.created.add(widget.label);
  }

  @override
  Widget build(BuildContext context) {
    ticking = TickerMode.of(context);
    return Center(
      child: TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('${widget.label}:$taps'),
      ),
    );
  }
}

/// A shell like the app's: the tab list is rebuilt from scratch every time.
Widget _shell(int index, List<String> created, {int count = 3}) =>
    LazyIndexedStack(
      index: index,
      children: [
        for (var i = 0; i < count; i++) _Tab('t$i', created),
      ],
    );

_TabState _state(WidgetTester tester, String label) => tester.state<_TabState>(
      find.byWidgetPredicate(
        (w) => w is _Tab && w.label == label,
        skipOffstage: false,
      ),
    );

Finder _tab(String label) => find.byWidgetPredicate(
      (w) => w is _Tab && w.label == label,
      skipOffstage: false,
    );

void main() {
  setUpAll(initHarness);

  group('LazyIndexedStack layout', () {
    testOnEverySurface(
      'hosts long, scrolling tab bodies',
      (s) => LazyIndexedStack(
        index: 1,
        children: [
          ListView(children: [Text(LongText.of(s))]),
          ListView(
            children: [
              for (var i = 0; i < 40; i++) Text('${LongText.of(s)} $i'),
            ],
          ),
          const Placeholder(),
        ],
      ),
      verify: (tester, s) async {
        expect(find.text('${LongText.of(s)} 0'), findsOneWidget);
        // The unvisited tabs cost nothing: no ListView, no Placeholder.
        expect(find.byType(ListView, skipOffstage: false), findsOneWidget);
        expect(find.byType(Placeholder, skipOffstage: false), findsNothing);
      },
    );
  });

  group('LazyIndexedStack state', () {
    testWidgets('a tab keeps its state when you leave and come back',
        (tester) async {
      final created = <String>[];
      await pumpSurface(tester, phoneEn, _shell(0, created));
      await tester.tap(find.text('t0:0'));
      await tester.pump();
      await tester.tap(find.text('t0:1'));
      await tester.pump();
      expect(find.text('t0:2'), findsOneWidget);

      await pumpSurface(tester, phoneEn, _shell(1, created));
      expect(find.text('t0:2'), findsNothing); // offstage
      await pumpSurface(tester, phoneEn, _shell(0, created));
      expect(find.text('t0:2'), findsOneWidget);
      expect(_state(tester, 't0').taps, 2);
      // One State per tab, ever.
      expect(created, ['t0', 't1']);
    });

    testWidgets('a scroll offset survives a tab switch', (tester) async {
      Widget shell(int index) => LazyIndexedStack(
            index: index,
            children: [
              ListView.builder(
                key: const PageStorageKey('list'),
                itemCount: 100,
                itemBuilder: (_, i) => SizedBox(height: 50, child: Text('r$i')),
              ),
              const Text('other'),
            ],
          );
      await pumpSurface(tester, phoneEn, shell(0));
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();
      final offset = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;
      expect(offset, greaterThan(0));

      await pumpSurface(tester, phoneEn, shell(1));
      await pumpSurface(tester, phoneEn, shell(0));
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        offset,
      );
    });

    testWidgets('a text field keeps its text across a switch', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      Widget shell(int index) => LazyIndexedStack(
            index: index,
            children: [
              TextField(controller: controller),
              const Text('other'),
            ],
          );
      await pumpSurface(tester, phoneEn, shell(0));
      await tester.enterText(find.byType(TextField), 'draft note');
      await pumpSurface(tester, phoneEn, shell(1));
      await pumpSurface(tester, phoneEn, shell(0));
      expect(find.text('draft note'), findsOneWidget);
    });

    testWidgets('a tab that was never opened is never built, however often '
        'the others switch', (tester) async {
      final created = <String>[];
      for (final index in [0, 2, 0, 2, 2, 0]) {
        await pumpSurface(tester, phoneEn, _shell(index, created));
      }
      expect(created, ['t0', 't2']);
      expect(_tab('t1'), findsNothing);
      await pumpSurface(tester, phoneEn, _shell(1, created));
      expect(created, ['t0', 't2', 't1']);
    });
  });

  group('LazyIndexedStack offstage tabs', () {
    testWidgets('only the selected tab is visible and hit-testable',
        (tester) async {
      final created = <String>[];
      await pumpSurface(tester, phoneEn, _shell(0, created));
      await pumpSurface(tester, phoneEn, _shell(1, created));
      expect(find.text('t1:0'), findsOneWidget);
      expect(find.text('t0:0'), findsNothing);
      expect(find.text('t0:0', skipOffstage: false), findsOneWidget);
      // A tap aimed at the hidden tab lands on the visible one.
      await tester.tap(find.text('t1:0'));
      await tester.pump();
      expect(_state(tester, 't1').taps, 1);
      expect(_state(tester, 't0').taps, 0);
    });

    testWidgets('a hidden tab pauses its tickers and resumes when shown',
        (tester) async {
      // A plain IndexedStack keeps animations in hidden tabs running (it builds
      // them with maintainAnimation). The lazy stack mutes them instead, so a
      // pulse on a tab the user left does not draw frames all day.
      final created = <String>[];
      await pumpSurface(tester, phoneEn, _shell(0, created));
      expect(TickerMode.of(tester.element(_tab('t0'))), isTrue);
      await pumpSurface(tester, phoneEn, _shell(1, created));
      expect(TickerMode.of(tester.element(_tab('t1'))), isTrue);
      expect(TickerMode.of(tester.element(_tab('t0'))), isFalse);
      await pumpSurface(tester, phoneEn, _shell(0, created));
      expect(TickerMode.of(tester.element(_tab('t0'))), isTrue);
      expect(TickerMode.of(tester.element(_tab('t1'))), isFalse);
      // State survived the pause.
      expect(created.where((c) => c == 't0'), hasLength(1));
    });

    testWidgets('hidden tabs are left out of semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final created = <String>[];
      await pumpSurface(tester, phoneEn, _shell(0, created));
      await pumpSurface(tester, phoneEn, _shell(1, created));
      expect(find.bySemanticsLabel('t1:0'), findsOneWidget);
      expect(find.bySemanticsLabel('t0:0'), findsNothing);
      handle.dispose();
    });

    testWidgets('the stack sizes to the tabs that were built', (tester) async {
      Widget shell(int index) => Center(
            child: LazyIndexedStack(
              index: index,
              children: const [
                SizedBox(width: 50, height: 50),
                SizedBox(width: 200, height: 120),
              ],
            ),
          );
      await pumpSurface(tester, phoneEn, shell(0));
      // A plain IndexedStack would already be 200×120 here.
      expect(tester.getSize(find.byType(LazyIndexedStack)), const Size(50, 50));
      await pumpSurface(tester, phoneEn, shell(1));
      expect(tester.getSize(find.byType(LazyIndexedStack)),
          const Size(200, 120));
    });

    testWidgets('children align to the reading start by default',
        (tester) async {
      const small = Key('small');
      Widget shell(int index) => Center(
            child: LazyIndexedStack(
              index: index,
              children: const [
                SizedBox(key: small, width: 10, height: 10),
                SizedBox(width: 100, height: 100),
              ],
            ),
          );
      Future<(Offset, Offset)> corners(Surface s) async {
        await pumpSurface(tester, s, shell(1));
        await pumpSurface(tester, s, shell(0));
        final stack = find.byType(LazyIndexedStack);
        return (
          tester.getTopRight(find.byKey(small)) - tester.getTopRight(stack),
          tester.getTopLeft(find.byKey(small)) - tester.getTopLeft(stack),
        );
      }

      final (_, enFromLeft) = await corners(phoneEn);
      expect(enFromLeft, Offset.zero);
      final (arFromRight, _) = await corners(phoneAr);
      expect(arFromRight, Offset.zero);
    });

    testWidgets('an explicit alignment is honoured', (tester) async {
      const small = Key('small');
      Widget shell(int index) => Center(
            child: LazyIndexedStack(
              index: index,
              alignment: Alignment.bottomRight,
              children: const [
                SizedBox(key: small, width: 10, height: 10),
                SizedBox(width: 100, height: 100),
              ],
            ),
          );
      await pumpSurface(tester, phoneEn, shell(1));
      await pumpSurface(tester, phoneEn, shell(0));
      expect(tester.getBottomRight(find.byKey(small)),
          tester.getBottomRight(find.byType(LazyIndexedStack)));
    });
  });

  group('LazyIndexedStack children changes', () {
    testWidgets('a tab added later can be opened, and old tabs keep state',
        (tester) async {
      final created = <String>[];
      await pumpSurface(tester, phoneEn, _shell(0, created, count: 2));
      await tester.tap(find.text('t0:0'));
      await tester.pump();
      // A manager gets an extra tab after a role refresh.
      await pumpSurface(tester, phoneEn, _shell(0, created, count: 3));
      expect(_tab('t2'), findsNothing);
      await pumpSurface(tester, phoneEn, _shell(2, created, count: 3));
      expect(find.text('t2:0'), findsOneWidget);
      expect(_state(tester, 't0').taps, 1);
      expect(created, ['t0', 't2']);
    });

    testWidgets('removing a tab drops it without a RangeError',
        (tester) async {
      final created = <String>[];
      await pumpSurface(tester, phoneEn, _shell(2, created));
      await pumpSurface(tester, phoneEn, _shell(0, created));
      await pumpSurface(tester, phoneEn, _shell(0, created, count: 2));
      expect(tester.takeException(), isNull);
      expect(_tab('t2'), findsNothing);
      // Growing back does not resurrect the dropped tab's "visited" mark.
      await pumpSurface(tester, phoneEn, _shell(0, created, count: 3));
      expect(_tab('t2'), findsNothing);
      await pumpSurface(tester, phoneEn, _shell(2, created, count: 3));
      expect(created, ['t2', 't0', 't2']);
    });

    testWidgets('swapping a tab widget of the same type keeps its state',
        (tester) async {
      final created = <String>[];
      await pumpSurface(tester, phoneEn, _shell(0, created));
      await tester.tap(find.text('t0:0'));
      await tester.pump();
      // Same position, same type, no key: Flutter updates in place.
      await pumpSurface(
        tester,
        phoneEn,
        LazyIndexedStack(index: 0, children: [_Tab('t0', created)]),
      );
      expect(find.text('t0:1'), findsOneWidget);
      expect(created, ['t0']);
    });

    testWidgets('a keyed tab moved to another slot is rebuilt fresh',
        (tester) async {
      final created = <String>[];
      await pumpSurface(
        tester,
        phoneEn,
        LazyIndexedStack(
          index: 0,
          children: [
            _Tab('a', created, key: const ValueKey('a')),
            _Tab('b', created, key: const ValueKey('b')),
          ],
        ),
      );
      await pumpSurface(
        tester,
        phoneEn,
        LazyIndexedStack(
          index: 0,
          children: [
            _Tab('b', created, key: const ValueKey('b')),
            _Tab('a', created, key: const ValueKey('a')),
          ],
        ),
      );
      // Slot 0 is the visited one; 'b' now sits there and gets built, while
      // 'a' moved to an unvisited slot and is not.
      expect(find.text('b:0'), findsOneWidget);
      expect(_tab('a'), findsNothing);
      expect(created, ['a', 'b']);
    });
  });
}
