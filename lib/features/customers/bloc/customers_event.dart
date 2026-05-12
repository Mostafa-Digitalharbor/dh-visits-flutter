part of 'customers_bloc.dart';

sealed class CustomersEvent extends Equatable {
  const CustomersEvent();
  @override
  List<Object?> get props => [];
}

class CustomersLoadRequested extends CustomersEvent {
  const CustomersLoadRequested();
}

class CustomersSearchChanged extends CustomersEvent {
  final String query;
  const CustomersSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}
