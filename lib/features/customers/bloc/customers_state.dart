part of 'customers_bloc.dart';

enum CustomersStatus { initial, loading, success, failure }

class CustomersState extends Equatable {
  final CustomersStatus status;
  final List<Customer> items;
  final String? search;
  final ApiException? error;

  const CustomersState({
    this.status = CustomersStatus.initial,
    this.items = const [],
    this.search,
    this.error,
  });

  CustomersState copyWith({
    CustomersStatus? status,
    List<Customer>? items,
    String? search,
    ApiException? error,
  }) =>
      CustomersState(
        status: status ?? this.status,
        items: items ?? this.items,
        search: search ?? this.search,
        error: error,
      );

  @override
  List<Object?> get props => [status, items, search, error];
}
