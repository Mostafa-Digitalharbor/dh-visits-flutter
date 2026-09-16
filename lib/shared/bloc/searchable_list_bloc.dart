import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_exceptions.dart';

/// Lifecycle of a searchable list fetch.
enum ListStatus { initial, loading, success, failure }

/// Events understood by every [SearchableListBloc].
///
/// Shared rather than per-feature: the customers and employees blocs each had
/// their own identical `LoadRequested` / `SearchChanged` / `Reset` trio, and
/// the duplication is what let their `_onLoad` bodies drift apart (only one of
/// them had the generic `catch` that stops a parse error freezing the UI).
sealed class SearchableListEvent extends Equatable {
  const SearchableListEvent();
  @override
  List<Object?> get props => [];
}

class ListLoadRequested extends SearchableListEvent {
  const ListLoadRequested();
}

class ListSearchChanged extends SearchableListEvent {
  final String query;
  const ListSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}

/// Clear back to the initial state.
///
/// These blocs are app-scoped so they outlive a session; without this the next
/// user inherits the previous user's cached rows *and* their search filter —
/// which reads as "you have no customers" rather than a stale filter.
class ListReset extends SearchableListEvent {
  const ListReset();
}

/// State shared by searchable list screens. Features subclass this to keep a
/// concrete, type-safe state class while inheriting the shape.
abstract class SearchableListState<T> extends Equatable {
  final ListStatus status;
  final List<T> items;
  final String? search;
  final ApiException? error;

  const SearchableListState({
    this.status = ListStatus.initial,
    this.items = const [],
    this.search,
    this.error,
  });

  /// Returns a copy of *this concrete subclass*. `error` is deliberately not
  /// coalesced (`error ?? this.error`): a successful reload must be able to
  /// clear a previous failure by passing null.
  SearchableListState<T> copyWithBase({
    ListStatus? status,
    List<T>? items,
    String? search,
    ApiException? error,
  });

  bool get isLoading => status == ListStatus.loading;
  bool get hasError => status == ListStatus.failure;

  @override
  List<Object?> get props => [status, items, search, error];
}

/// Load / search / reset for a list backed by a single repository call.
///
/// Subclasses supply the fetch and the initial state; everything else — the
/// event wiring, the loading emit, both catch arms and the search round-trip —
/// lives here once.
abstract class SearchableListBloc<T, S extends SearchableListState<T>>
    extends Bloc<SearchableListEvent, S> {
  /// Fetches the rows. `search` is null or empty when unfiltered.
  final Future<List<T>> Function({String? search}) loader;

  final S _initialState;

  /// Bumped by every [ListReset]. A load that started before the bump belongs
  /// to the previous session and must not write its rows into the reset state.
  int _generation = 0;

  SearchableListBloc({required this.loader, required S initialState})
      : _initialState = initialState,
        super(initialState) {
    // Restartable: a newer load (the user typed again) cancels the one in
    // flight, so a slow answer for an old query can't land after — and
    // overwrite — the answer for the current one.
    on<ListLoadRequested>(_onLoad, transformer: restartable());
    on<ListSearchChanged>(_onSearch);
    on<ListReset>((_, emit) {
      _generation++;
      emit(_initialState);
    });
  }

  Future<void> _onLoad(ListLoadRequested event, Emitter<S> emit) async {
    final generation = _generation;
    emit(state.copyWithBase(status: ListStatus.loading) as S);
    try {
      final items = await loader(search: state.search);
      if (generation != _generation) return;
      emit(state.copyWithBase(
        status: ListStatus.success,
        items: items,
        error: null,
      ) as S);
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(state.copyWithBase(status: ListStatus.failure, error: e) as S);
    } catch (e) {
      if (generation != _generation) return;
      // Never leave the UI stuck on the loading skeleton. Repositories map raw
      // Odoo rows client-side, so a schema change throws a TypeError rather
      // than an ApiException and would otherwise escape the handler above.
      emit(state.copyWithBase(
        status: ListStatus.failure,
        error: ApiException.unexpected(e),
      ) as S);
    }
  }

  Future<void> _onSearch(ListSearchChanged event, Emitter<S> emit) async {
    emit(state.copyWithBase(search: event.query) as S);
    add(const ListLoadRequested());
  }
}
