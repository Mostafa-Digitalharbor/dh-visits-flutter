import '../../../core/api/api_exceptions.dart';
import '../../../shared/bloc/searchable_list_bloc.dart';
import '../data/customers_repository.dart';
import '../data/models/customer.dart';

part 'customers_state.dart';

/// Customer list + search. All of the load / search / reset machinery lives in
/// [SearchableListBloc]; this only binds it to the repository call.
class CustomersBloc extends SearchableListBloc<Customer, CustomersState> {
  CustomersBloc({required CustomersRepository repository})
      : super(
          loader: repository.list,
          initialState: const CustomersState(),
        );
}
