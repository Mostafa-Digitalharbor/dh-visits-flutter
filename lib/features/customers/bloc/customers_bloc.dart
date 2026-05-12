import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/customers_repository.dart';
import '../data/models/customer.dart';

part 'customers_event.dart';
part 'customers_state.dart';

class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  final CustomersRepository repository;

  CustomersBloc({required this.repository}) : super(const CustomersState()) {
    on<CustomersLoadRequested>(_onLoad);
    on<CustomersSearchChanged>(_onSearch);
  }

  Future<void> _onLoad(
    CustomersLoadRequested event,
    Emitter<CustomersState> emit,
  ) async {
    emit(state.copyWith(status: CustomersStatus.loading));
    try {
      final items = await repository.list(search: state.search);
      emit(state.copyWith(
        status: CustomersStatus.success,
        items: items,
        error: null,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
          status: CustomersStatus.failure, error: e));
    }
  }

  Future<void> _onSearch(
    CustomersSearchChanged event,
    Emitter<CustomersState> emit,
  ) async {
    emit(state.copyWith(search: event.query));
    add(const CustomersLoadRequested());
  }
}
