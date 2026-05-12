part of 'visits_list_bloc.dart';

enum VisitsListStatus { initial, loading, success, failure }

enum VisitsFilter { today, all }

class VisitsListState extends Equatable {
  final VisitsListStatus status;
  final List<Visit> items;
  final VisitsFilter filter;
  final ApiException? error;

  /// Client-side substring filter on customer name. Empty = show all.
  final String searchQuery;

  const VisitsListState({
    this.status = VisitsListStatus.initial,
    this.items = const [],
    this.filter = VisitsFilter.today,
    this.error,
    this.searchQuery = '',
  });

  VisitsListState copyWith({
    VisitsListStatus? status,
    List<Visit>? items,
    VisitsFilter? filter,
    ApiException? error,
    String? searchQuery,
  }) =>
      VisitsListState(
        status: status ?? this.status,
        items: items ?? this.items,
        filter: filter ?? this.filter,
        error: error,
        searchQuery: searchQuery ?? this.searchQuery,
      );

  @override
  List<Object?> get props => [status, items, filter, error, searchQuery];
}
