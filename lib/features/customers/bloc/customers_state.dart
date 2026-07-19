part of 'customers_bloc.dart';

class CustomersState extends SearchableListState<Customer> {
  const CustomersState({
    super.status,
    super.items,
    super.search,
    super.error,
  });

  @override
  CustomersState copyWithBase({
    ListStatus? status,
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
}
