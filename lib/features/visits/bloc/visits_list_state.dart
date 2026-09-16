part of 'visits_list_bloc.dart';

enum VisitsListStatus { initial, loading, success, failure }

/// Which slice of visits the list is showing. `mine` uses the REST `/my`
/// endpoint; the manager scopes use `call_kw` (record rules scope them to the
/// manager's hierarchy).
enum VisitListScope { mine, pending, team, escalated }

/// A preset slice the dashboard's KPI tiles open the list on. Applied on top of
/// [VisitsListState.stateFilter] and the search, client-side.
enum VisitsListFocus {
  all,

  /// [Visit.isOverdue] — the "Overdue" tile.
  overdue,

  /// Visits on today's calendar — the "Today" tile.
  today,

  /// Visits running right now — the "In progress" tile.
  inProgress;

  bool matches(Visit v, DateTime now) => switch (this) {
    all => true,
    overdue => v.isOverdueAt(now),
    today => v.isOnDay(now),
    inProgress => v.isInProgress,
  };
}

class VisitsListState extends Equatable {
  final VisitsListStatus status;
  final List<Visit> items;
  final VisitListScope scope;
  final ApiException? error;

  /// Client-side substring filter on customer / reference / purpose.
  final String searchQuery;

  /// Optional client-side filter on a single workflow state. `null` = all.
  final VisitState? stateFilter;

  /// The dashboard preset the list was opened with.
  final VisitsListFocus focus;

  VisitsListState({
    this.status = VisitsListStatus.initial,
    this.items = const [],
    this.scope = VisitListScope.mine,
    this.error,
    this.searchQuery = '',
    this.stateFilter,
    this.focus = VisitsListFocus.all,
  });

  /// [items] narrowed by [searchQuery] and [stateFilter] — what the list
  /// actually renders.
  ///
  /// `late final`, so the sweep runs at most once per state instance and only
  /// if something reads it. The page used to filter inside `build()`, which
  /// lower-cased three fields of all 200 rows on *every* rebuild — and with the
  /// search field firing an event per keystroke, that was a full re-filter and
  /// re-layout on each character typed. The class gives up `const` for this;
  /// [initial] covers the one place that needed a compile-time constant.
  late final List<Visit> visible = _filter();

  List<Visit> _filter() {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty && stateFilter == null && focus == VisitsListFocus.all) {
      return items;
    }
    final now = DateTime.now();
    return items
        .where((v) {
          if (stateFilter != null && v.state != stateFilter) return false;
          if (!focus.matches(v, now)) return false;
          if (q.isEmpty) return true;
          return (v.partnerName ?? '').toLowerCase().contains(q) ||
              (v.name ?? '').toLowerCase().contains(q) ||
              (v.purpose ?? '').toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  /// Whether a state filter or a dashboard preset narrows the list, so an
  /// empty result means "nothing matches" rather than "nothing exists".
  bool get isFiltered => stateFilter != null || focus != VisitsListFocus.all;

  /// The pristine state. A getter rather than a `static final` so a reset never
  /// hands back an instance whose [visible] cache was already forced.
  static VisitsListState get initial => VisitsListState();

  VisitsListState copyWith({
    VisitsListStatus? status,
    List<Visit>? items,
    VisitListScope? scope,
    ApiException? error,
    String? searchQuery,
    VisitState? stateFilter,
    bool clearStateFilter = false,
    VisitsListFocus? focus,
  }) => VisitsListState(
    status: status ?? this.status,
    items: items ?? this.items,
    scope: scope ?? this.scope,
    error: error,
    searchQuery: searchQuery ?? this.searchQuery,
    stateFilter: clearStateFilter ? null : (stateFilter ?? this.stateFilter),
    focus: focus ?? this.focus,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    scope,
    error,
    searchQuery,
    stateFilter,
    focus,
  ];
}
