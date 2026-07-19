import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_exceptions.dart';
import '../../visits/data/models/visit_activity.dart';
import '../../visits/data/visits_repository.dart';

enum NotificationsStatus { initial, loading, success, failure }

class NotificationsState extends Equatable {
  final NotificationsStatus status;
  final List<VisitActivity> activities;
  final ApiException? error;

  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.activities = const [],
    this.error,
  });

  int get count => activities.length;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<VisitActivity>? activities,
    ApiException? error,
  }) =>
      NotificationsState(
        status: status ?? this.status,
        activities: activities ?? this.activities,
        error: error,
      );

  @override
  List<Object?> get props => [status, activities, error];
}

/// Loads the current user's pending visit activities (the in-app notification
/// feed). Backed by `mail.activity` — see [VisitsRepository.myActivities].
class NotificationsCubit extends Cubit<NotificationsState> {
  final VisitsRepository repository;

  NotificationsCubit({required this.repository})
      : super(const NotificationsState());

  Future<void> load() async {
    emit(state.copyWith(status: NotificationsStatus.loading, error: null));
    try {
      final activities = await repository.myActivities();
      // isClosed: this cubit is page-scoped, so popping the page while the
      // read is in flight disposes it before this runs — and emitting on a
      // closed cubit throws.
      if (isClosed) return;
      emit(state.copyWith(
        status: NotificationsStatus.success,
        activities: activities,
      ));
    } on ApiException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: NotificationsStatus.failure, error: e));
    } catch (e) {
      // Without this, an unexpected failure (a parse error, say) escaped
      // uncaught and left the page on its spinner forever.
      if (isClosed) return;
      emit(state.copyWith(
        status: NotificationsStatus.failure,
        error: ApiException.unexpected(e),
      ));
    }
  }
}
