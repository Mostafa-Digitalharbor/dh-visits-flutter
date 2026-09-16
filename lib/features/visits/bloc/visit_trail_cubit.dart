import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/constants.dart';
import '../data/models/visit_location_log.dart';
import '../data/visit_trail_tracker.dart';
import '../data/visits_repository.dart';

enum VisitTrailStatus { loading, ready, error }

class VisitTrailState extends Equatable {
  final VisitTrailStatus status;
  final VisitTrack track;
  final ApiException? error;

  /// Fixes sitting in the device buffer that the server hasn't accepted yet.
  /// Shown so the rep can tell "the path stops here because I lost signal"
  /// apart from "the path stops here because I stopped moving".
  final int pendingUploads;

  const VisitTrailState({
    this.status = VisitTrailStatus.loading,
    this.track = VisitTrack.empty,
    this.error,
    this.pendingUploads = 0,
  });

  VisitTrailState copyWith({
    VisitTrailStatus? status,
    VisitTrack? track,
    ApiException? error,
    int? pendingUploads,
  }) => VisitTrailState(
    status: status ?? this.status,
    track: track ?? this.track,
    // One-shot, like the other cubits in this feature: an error that
    // survived into the next successful read would keep a stale banner up.
    error: error,
    pendingUploads: pendingUploads ?? this.pendingUploads,
  );

  bool get hasPath => track.hasPath;

  @override
  List<Object?> get props => [status, track, error, pendingUploads];
}

/// Reads one visit's GPS trail and keeps it current.
///
/// While the visit is running the trail is still growing, so the cubit polls
/// and also listens to the tracker: a flush that lands new points bumps
/// [VisitTrailTracker.revision] and we refetch immediately rather than waiting
/// out the poll interval. For a finished visit nothing changes, so it reads
/// once and stops.
class VisitTrailCubit extends Cubit<VisitTrailState> {
  final VisitsRepository repository;
  final VisitTrailTracker? tracker;
  final int visitId;

  /// Whether the visit is still running. Drives polling — a `done` visit's
  /// trail is final and polling it would be pure battery.
  bool get live => _live;
  bool _live;

  Timer? _poll;

  /// Numbers each [load]; only the newest may land. A poll and a
  /// flush-triggered refetch overlap, and the slower (older) answer used to
  /// replace the newer path.
  int _loadSeq = 0;

  VoidCallback? _revisionListener;
  VoidCallback? _pendingListener;

  VisitTrailCubit({
    required this.repository,
    required this.visitId,
    this.tracker,
    bool live = false,
  }) : _live = live,
       super(const VisitTrailState()) {
    final t = tracker;
    if (t != null) {
      _revisionListener = () => unawaited(load(silent: true));
      t.revision.addListener(_revisionListener!);
      _pendingListener = () {
        if (isClosed) return;
        emit(state.copyWith(pendingUploads: t.pendingCount.value));
      };
      t.pendingCount.addListener(_pendingListener!);
    }
    if (live) _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      AppConstants.trailLiveRefreshInterval,
      (_) => unawaited(load(silent: true)),
    );
  }

  /// Follows the visit starting or ending while its screen is open — or a
  /// screen opened without knowing (a notification tap) learning that the
  /// visit is running. Polling used to be fixed at construction, so such a
  /// screen never refreshed a route that was still growing.
  void setLive(bool live) {
    if (isClosed || live == _live) return;
    _live = live;
    if (live) {
      _startPolling();
    } else {
      _poll?.cancel();
      _poll = null;
    }
    // Either way the path just changed: it is growing, or it was closed off.
    unawaited(load(silent: true));
  }

  /// Fetches the trail. [silent] keeps the current points on screen while the
  /// request is in flight — a poll must never blink the drawn path back to a
  /// spinner, and a failed poll must not replace a good path with an error.
  Future<void> load({bool silent = false}) async {
    if (isClosed) return;
    final seq = ++_loadSeq;
    if (!silent) {
      emit(state.copyWith(status: VisitTrailStatus.loading));
    }
    try {
      final track = await repository.readTrack(visitId);
      if (isClosed || seq != _loadSeq) return;
      emit(
        state.copyWith(
          status: VisitTrailStatus.ready,
          track: track,
          pendingUploads: tracker?.pendingCount.value ?? 0,
        ),
      );
    } catch (e) {
      if (isClosed || seq != _loadSeq) return;
      if (silent && state.status == VisitTrailStatus.ready) return;
      emit(
        state.copyWith(
          status: VisitTrailStatus.error,
          error: e is ApiException ? e : ApiException.unexpected(e),
        ),
      );
    }
  }

  /// Pushes the device buffer now, then re-reads — the "upload my points"
  /// action behind the pending-uploads chip.
  ///
  /// Returns how many fixes are still on the device afterwards, so the tap
  /// can say whether it worked: the flush itself never throws, and offline it
  /// simply sends nothing.
  Future<int> flushAndReload() async {
    // What the native capture recorded since its last drain goes out too.
    await tracker?.drain();
    await tracker?.flushNow(probe: true);
    await load(silent: true);
    return tracker?.pendingCount.value ?? 0;
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    final t = tracker;
    if (t != null) {
      if (_revisionListener != null) {
        t.revision.removeListener(_revisionListener!);
      }
      if (_pendingListener != null) {
        t.pendingCount.removeListener(_pendingListener!);
      }
    }
    return super.close();
  }
}
