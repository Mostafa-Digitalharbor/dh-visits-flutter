import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/pending_actions_queue.dart';
import '../../../core/utils/communications.dart';
import '../../../core/utils/user_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../customers/data/customers_repository.dart';
import '../../customers/data/models/customer.dart';
import '../../employees/data/employees_repository.dart';
import '../../employees/data/models/employee.dart';
import '../bloc/visit_bloc.dart';
import '../bloc/visits_list_bloc.dart';
import '../data/models/visit.dart';
import '../data/models/visit_type.dart';
import '../data/visits_repository.dart';
import 'report_sheet.dart';
import 'visit_state_picker.dart';

/// Single-visit detail screen. Used by both User and Manager roles.
/// Behavior diverges based on `AuthBloc.state.user.canEditVisits`:
/// - **Manager**: can edit `visit_date` and `description` at any time.
/// - **User**: can only edit `description` while the visit is checked-in.
/// Both roles can drive the check-in / check-out transitions when the
/// visit's current state allows it.
class VisitDetailPage extends StatefulWidget {
  final int visitId;
  final Visit? initial;

  const VisitDetailPage({super.key, required this.visitId, this.initial});

  @override
  State<VisitDetailPage> createState() => _VisitDetailPageState();
}

class _VisitDetailPageState extends State<VisitDetailPage> {
  Visit? _visit;
  bool _busy = false;
  // True while a list-refresh is in flight. The body switches to the
  // shimmer placeholder while loading so the admin doesn't see the old
  // card values flicker into the new ones.
  bool _loading = false;
  late TextEditingController _notesCtrl;

  bool _editingNotes = false;
  DateTime? _editedVisitDate;

  /// Admin can swap the visit's customer (`partner_id`) without leaving
  /// this screen. We hold the chosen Customer until save.
  Customer? _editedCustomer;

  /// Same for swapping the assigned employee (`salesperson_id`). The
  /// picker writes the user id back via Employee.userId.
  Employee? _editedEmployee;

  /// Admin can flip the lifecycle state (Draft / Submit / Done) directly
  /// from the detail screen. Held until save like the other edits.
  VisitLifecycleState? _editedLifecycle;

  /// Admin can tag/retag the visit's kind (`visit_type_id`). Cleared by
  /// the picker's "x" trailing button, which sets this to a sentinel
  /// with id `-1` so we know the admin wants to *remove* the type vs.
  /// just hasn't touched it.
  VisitType? _editedVisitType;

  static final _odooDateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _odooDateOnly = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _visit = widget.initial;
    _notesCtrl = TextEditingController();
    if (_visit == null) {
      _refreshFromServer();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  /// True when the logged-in user is a manager / admin. Used to decide
  /// whether dispatched `VisitsListLoadRequested` events should also
  /// surface drafts, and whether the visit refresh call here needs the
  /// same.
  bool get _isManager =>
      context.read<AuthBloc>().state.user?.canEditVisits ?? false;

  Future<void> _refreshFromServer() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list =
          await sl<VisitsRepository>().list(includeDrafts: _isManager);
      final fresh = list.firstWhere(
        (v) => v.id == widget.visitId,
        orElse: () => _visit ?? Visit(id: widget.visitId),
      );
      if (mounted) setState(() => _visit = fresh);
    } on ApiException catch (e) {
      if (mounted) context.showSnack(e.localize(context));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkIn() async {
    final visit = _visit;
    if (visit == null) return;
    setState(() => _busy = true);
    try {
      final ok = await sl<LocationService>().ensurePermission();
      if (!ok) {
        if (mounted) {
          context.showSnack(context.s.errLocationPermission);
        }
        return;
      }
      final pos = await sl<LocationService>().getCurrent();
      final nowUtc = DateTime.now().toUtc();
      final payload = <String, dynamic>{
        'state': 'submit',
        'check_in_date_time': _odooDateFmt.format(nowUtc),
        'check_in_lat': pos.latitude,
        'check_in_lng': pos.longitude,
      };
      try {
        await sl<VisitsRepository>().update(visit.id, payload);
      } on ApiException catch (e) {
        if (_isOffline(e)) {
          // Network down — save locally so the user's tap isn't lost.
          // Auto-retry kicks in via PendingActionsQueue once
          // connectivity recovers.
          await sl<PendingActionsQueue>().enqueue(visit.id, payload);
          HapticFeedback.mediumImpact();
          if (mounted) {
            context.showSnack(
              context.s.offlineCheckInQueued,
              kind: SnackKind.info,
            );
          }
          return;
        }
        rethrow;
      }
      HapticFeedback.mediumImpact();
      final customerName = visit.customerName;
      await _refreshFromServer();
      if (mounted) {
        // Refresh the surrounding list + tell VisitBloc to re-pick the
        // active visit so the home shell switches to the persistent bar.
        context
            .read<VisitsListBloc>()
            .add(VisitsListLoadRequested(includeDrafts: _isManager));
        context.read<VisitBloc>().add(const VisitResumeRequested());
        context.showSnack(
          customerName != null && customerName.isNotEmpty
              ? context.s.visitDetailCheckInStartedAt(customerName)
              : context.s.checkInSuccess,
          kind: SnackKind.success,
        );
      }
    } on ApiException catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) {
        context.showSnack(e.localize(context), kind: SnackKind.error);
      }
    } catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) context.showSnack(e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// True when the API failure was a "couldn't reach the server"
  /// type rather than a real server-side rejection. Only these warrant
  /// queueing — validation or permission errors won't fix themselves.
  bool _isOffline(ApiException e) =>
      e.code == ApiErrorCode.network || e.code == ApiErrorCode.timeout;

  Future<void> _checkOut() async {
    final visit = _visit;
    if (visit == null) return;
    // Field check-out opens the report sheet first (outcome + notes + photo +
    // signature). Dismissing it cancels the check-out.
    final report = await showReportSheet(context);
    if (report == null || !mounted) return;
    final outcomeLabel = switch (report.outcome) {
      VisitOutcome.done => context.s.reportOutcomeDone,
      VisitOutcome.postponed => context.s.reportOutcomePostponed,
      VisitOutcome.absent => context.s.reportOutcomeAbsent,
    };
    final reportNotes = [outcomeLabel, report.notes].where((s) => s.isNotEmpty).join(' — ');
    setState(() => _busy = true);
    try {
      final ok = await sl<LocationService>().ensurePermission();
      if (!ok) {
        if (mounted) context.showSnack(context.s.errLocationPermission);
        return;
      }
      final pos = await sl<LocationService>().getCurrent();
      final nowUtc = DateTime.now().toUtc();
      final payload = <String, dynamic>{
        'state': 'under_review',
        'check_out_date_time': _odooDateFmt.format(nowUtc),
        'check_out_lat': pos.latitude,
        'check_out_lng': pos.longitude,
      };
      if (reportNotes.isNotEmpty) {
        payload['description'] = reportNotes;
      }
      try {
        await sl<VisitsRepository>().update(visit.id, payload);
      } on ApiException catch (e) {
        if (_isOffline(e)) {
          await sl<PendingActionsQueue>().enqueue(visit.id, payload);
          HapticFeedback.mediumImpact();
          if (mounted) {
            context.showSnack(
              context.s.offlineCheckInQueued,
              kind: SnackKind.info,
            );
            context.read<VisitBloc>().add(const VisitCleared());
          }
          return;
        }
        rethrow;
      }
      HapticFeedback.mediumImpact();
      await _refreshFromServer();
      if (mounted) {
        context
            .read<VisitsListBloc>()
            .add(VisitsListLoadRequested(includeDrafts: _isManager));
        context.read<VisitBloc>().add(const VisitCleared());
        context.showSnack(context.s.checkOutSuccess, kind: SnackKind.success);
      }
    } on ApiException catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) {
        context.showSnack(e.localize(context), kind: SnackKind.error);
      }
    } catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) context.showSnack(e.toString(), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteVisit() async {
    final visit = _visit;
    if (visit == null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.s.confirmDeleteVisitTitle,
      message: context.s.confirmDeleteVisitMessage,
      icon: Icons.delete_forever_rounded,
      confirmLabel: context.s.visitDetailDelete,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await sl<VisitsRepository>().delete(visit.id);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      // If this visit was the active one, clear the persistent bar.
      final activeId = context.read<VisitBloc>().state.activeVisit?.id;
      if (activeId == visit.id) {
        context.read<VisitBloc>().add(const VisitCleared());
      }
      context
          .read<VisitsListBloc>()
          .add(VisitsListLoadRequested(includeDrafts: _isManager));
      context.showSnack(
        context.s.visitDeletedSuccess,
        kind: SnackKind.success,
      );
      // Pop is the LAST thing we do — once we pop, this State starts
      // deactivating and any subsequent setState/context lookup blows up
      // with "looking up a deactivated widget's ancestor".
      if (context.canPop()) {
        context.pop();
        return;
      }
      setState(() => _busy = false);
    } on ApiException catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) {
        context.showSnack(e.localize(context), kind: SnackKind.error);
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveEdits() async {
    final visit = _visit;
    if (visit == null) return;
    final payload = <String, dynamic>{};
    if (_editingNotes) {
      payload['description'] = _notesCtrl.text.trim();
    }
    if (_editedVisitDate != null) {
      payload['visit_date'] = _odooDateOnly.format(_editedVisitDate!);
    }
    if (_editedCustomer != null) {
      payload['partner_id'] = _editedCustomer!.id;
    }
    if (_editedEmployee != null) {
      payload['salesperson_id'] = _editedEmployee!.userId;
    }
    if (_editedLifecycle != null) {
      final wire = lifecycleToWire(_editedLifecycle!);
      if (wire != null) payload['state'] = wire;
    }
    if (_editedVisitType != null) {
      // id == -1 is the "cleared" sentinel set by the trailing X on the
      // visit-type picker row.
      payload['visit_type_id'] =
          _editedVisitType!.id == -1 ? false : _editedVisitType!.id;
    }
    if (payload.isEmpty) return;
    setState(() => _busy = true);
    try {
      await sl<VisitsRepository>().update(visit.id, payload);
      HapticFeedback.lightImpact();
      await _refreshFromServer();
      if (mounted) {
        context
            .read<VisitsListBloc>()
            .add(VisitsListLoadRequested(includeDrafts: _isManager));
        context.showSnack(
          context.s.visitDetailSaved,
          kind: SnackKind.success,
        );
        setState(() {
          _editingNotes = false;
          _editedVisitDate = null;
          _editedCustomer = null;
          _editedEmployee = null;
          _editedLifecycle = null;
          _editedVisitType = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        context.showSnack(e.localize(context), kind: SnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final canEdit = user?.canEditVisits ?? false;

    final visit = _visit;
    if (visit == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.s.visitDetailTitle)),
        body: const _DetailSkeleton(),
      );
    }

    // Keep the controller in sync when not actively editing.
    if (!_editingNotes) {
      _notesCtrl.text = visit.description ?? '';
    }

    // Finished visits become a read-only audit trail for the admin —
    // they already happened, so editable fields hide. Delete stays
    // available so the admin can clean up bad records or duplicates.
    final isFinished = visit.state == VisitStateType.checkedOut;
    final adminCanEdit = canEdit && !isFinished;

    final showSave = _hasUnsavedChanges(adminCanEdit);
    final cs = context.colors;
    const mapHeight = 300.0;
    const sheetOverlap = 26.0;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Map / brand header (fixed behind the sheet) ──────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mapHeight,
            child: _MapHeader(visit: visit),
          ),
          // ── Scrollable content sheet overlapping the map ─────────────────
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: mapHeight - sheetOverlap),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: context.x.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        if (_loading)
                          const _DetailSkeleton()
                        else if (canEdit)
                          _buildAdminBody(visit, allowEdits: adminCanEdit)
                        else
                          _buildUserBody(visit),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Floating chips over the map ──────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  _FloatingChip(
                    icon: context.isRtl ? Symbols.arrow_forward_ios : Symbols.arrow_back_ios_new,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  if (showSave) ...[
                    _FloatingChip(
                      icon: Symbols.save,
                      tint: cs.primary,
                      onTap: _busy ? null : _saveEdits,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (canEdit)
                    _FloatingChip(
                      icon: Symbols.delete,
                      tint: cs.error,
                      onTap: _busy ? null : _deleteVisit,
                    ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  /// True when the admin has touched any editable field but hasn't yet
  /// hit Save — drives the AppBar "Save changes" button.
  bool _hasUnsavedChanges(bool canEdit) {
    if (_editingNotes) return true;
    if (!canEdit) return false;
    return _editedVisitDate != null ||
        _editedCustomer != null ||
        _editedEmployee != null ||
        _editedLifecycle != null ||
        _editedVisitType != null;
  }

  /// User-facing screen — unchanged from before. Shows the basic visit
  /// info, timeline (when relevant), notes (editable mid-visit only),
  /// and the start/end buttons depending on state.
  Widget _buildUserBody(Visit visit) {
    final isActive = visit.state == VisitStateType.checkedIn;
    final isCompleted = visit.state == VisitStateType.checkedOut;
    final canCheckIn =
        !isActive && !isCompleted && visit.checkInTime == null;
    final notesEditableByUser = isActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CustomerBlock(visit: visit),
        const SizedBox(height: 14),
        _MetaBlock(
          visit: visit,
          canEdit: false,
          editedDate: null,
          editedCustomer: null,
          editedEmployee: null,
          editedLifecycle: null,
          editedVisitType: null,
          onEditDate: null,
          onEditCustomer: null,
          onEditEmployee: null,
          onEditLifecycle: null,
          onEditVisitType: null,
        ),
        if (visit.checkInTime != null) ...[
          const SizedBox(height: 14),
          _TimelineBlock(visit: visit),
        ],
        const SizedBox(height: 14),
        _NotesBlock(
          visit: visit,
          controller: _notesCtrl,
          editable: notesEditableByUser,
          editing: _editingNotes,
          onEditToggle: notesEditableByUser
              ? () => setState(() => _editingNotes = !_editingNotes)
              : null,
        ),
        const SizedBox(height: 8),
        if (!notesEditableByUser)
          _HintRow(text: context.s.visitDetailReadOnlyHint),
        if (notesEditableByUser)
          _HintRow(text: context.s.visitDetailNotesEditableHint),
        const SizedBox(height: 24),
        if (canCheckIn)
          AppButton(
            label: context.s.customerActionCheckIn,
            icon: Icons.login_rounded,
            loading: _busy,
            onPressed: _checkIn,
          ),
        if (isActive)
          AppButton.destructive(
            label: context.s.visitActionCheckOut,
            icon: Icons.logout_rounded,
            loading: _busy,
            onPressed: _checkOut,
          ),
      ],
    );
  }

  /// Manager-facing screen — fuller picture (employee location, range
  /// badges, status, customer address/phone). When `allowEdits` is true
  /// the admin can re-assign customer/employee, change the date, and
  /// edit notes. When the visit is already finished (checked_out),
  /// `allowEdits` is false and the page becomes a read-only audit view.
  Widget _buildAdminBody(Visit visit, {required bool allowEdits}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CustomerBlock(visit: visit),
        if (visit.isOverdue) ...[
          const SizedBox(height: 12),
          _OverdueBanner(visit: visit),
        ],
        const SizedBox(height: 14),
        _MetaBlock(
          visit: visit,
          canEdit: allowEdits,
          editedDate: _editedVisitDate,
          editedCustomer: _editedCustomer,
          editedEmployee: _editedEmployee,
          editedLifecycle: _editedLifecycle,
          editedVisitType: _editedVisitType,
          onEditDate: allowEdits ? _pickVisitDate : null,
          onEditCustomer: allowEdits ? _pickCustomer : null,
          onEditEmployee: allowEdits ? _pickEmployee : null,
          onEditLifecycle: allowEdits ? _pickLifecycle : null,
          onEditVisitType: allowEdits ? _pickVisitType : null,
        ),
        if (visit.lifecycleState == VisitLifecycleState.draft &&
            allowEdits) ...[
          const SizedBox(height: 14),
          AppButton(
            label: context.s.visitDetailSendToEmployee,
            icon: Icons.send_rounded,
            loading: _busy,
            onPressed: _sendToEmployee,
          ),
        ],
        if (visit.lifecycleState == VisitLifecycleState.underReview &&
            allowEdits) ...[
          const SizedBox(height: 14),
          AppButton(
            label: context.s.visitDetailMarkAsDone,
            icon: Icons.verified_rounded,
            loading: _busy,
            onPressed: _markAsDone,
          ),
        ],
        const SizedBox(height: 14),
        _AdminTimelineBlock(visit: visit),
        if (visit.hasCustomerLocation ||
            (visit.customerAddress?.isNotEmpty ?? false) ||
            (visit.customerPhone?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 14),
          _CustomerLocationBlock(visit: visit),
        ],
        const SizedBox(height: 14),
        _NotesBlock(
          visit: visit,
          controller: _notesCtrl,
          editable: allowEdits,
          editing: _editingNotes,
          onEditToggle: allowEdits
              ? () => setState(() => _editingNotes = !_editingNotes)
              : null,
        ),
        const SizedBox(height: 28),
        // Mirror of the AppBar trash icon — a fat destructive button at
        // the foot of the page is easier to discover and confirms the
        // admin's intent before tapping.
        AppButton.destructive(
          label: context.s.visitDetailDelete,
          icon: Icons.delete_forever_rounded,
          loading: _busy,
          onPressed: _deleteVisit,
        ),
      ],
    );
  }

  Future<void> _pickVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _editedVisitDate ?? _visit?.visitDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _editedVisitDate = picked);
    }
  }

  Future<void> _pickCustomer() async {
    final repo = sl<CustomersRepository>();
    final picked = await showPickerBottomSheet<Customer>(
      context: context,
      title: context.s.createVisitPickCustomer,
      searchHint: context.s.customersSearchHint,
      loader: (q) => repo.list(search: q),
      itemBuilder: (ctx, c) => ListTile(
        leading: CircleAvatar(
          backgroundColor: ctx.colors.primaryContainer,
          child: Text(
            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
            style: TextStyle(color: ctx.colors.onPrimaryContainer),
          ),
        ),
        title: Text(c.name),
        subtitle: c.address != null ? Text(c.address!) : null,
        onTap: () => Navigator.of(ctx).pop(c),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _editedCustomer = picked);
    }
  }

  Future<void> _pickLifecycle() async {
    final visit = _visit;
    final current = _editedLifecycle ?? visit?.lifecycleState ??
        VisitLifecycleState.draft;
    // Enforce the workflow rule: a visit the employee hasn't checked
    // out of can't be marked Under Review or Done. Once the visit has
    // been checked out, only Under Review / Done make sense — going
    // back to Draft/Submit would orphan the existing timestamps.
    final hasCheckOut = visit?.checkOutTime != null;
    final allowed = hasCheckOut
        ? const [VisitLifecycleState.underReview, VisitLifecycleState.done]
        : const [VisitLifecycleState.draft, VisitLifecycleState.submit];
    final picked = await showLifecycleStatePicker(
      context,
      current: current,
      allowedStates: allowed,
    );
    if (picked != null && mounted) {
      setState(() => _editedLifecycle = picked);
    }
  }

  Future<void> _pickVisitType() async {
    final repo = sl<VisitsRepository>();
    final picked = await showPickerBottomSheet<VisitType>(
      context: context,
      title: context.s.createVisitPickType,
      searchHint: context.s.pickerSearchHint,
      loader: (q) async {
        final all = await repo.listVisitTypes();
        if (q == null || q.isEmpty) return all;
        final lc = q.toLowerCase();
        return all.where((t) => t.name.toLowerCase().contains(lc)).toList();
      },
      itemBuilder: (ctx, t) => ListTile(
        leading: const Icon(Icons.label_outline_rounded),
        title: Text(t.name),
        onTap: () => Navigator.of(ctx).pop(t),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _editedVisitType = picked);
    }
  }

  /// Admin finished prepping the visit and wants to release it to the
  /// employee — flip `draft → submit` without going through the
  /// state picker. Mirror of `_markAsDone` at the other end of the
  /// workflow.
  Future<void> _sendToEmployee() async {
    final visit = _visit;
    if (visit == null) return;
    setState(() => _busy = true);
    try {
      await sl<VisitsRepository>().update(visit.id, {'state': 'submit'});
      HapticFeedback.mediumImpact();
      await _refreshFromServer();
      if (mounted) {
        context
            .read<VisitsListBloc>()
            .add(VisitsListLoadRequested(includeDrafts: _isManager));
        context.showSnack(
          context.s.visitDetailSentToEmployeeSuccess,
          kind: SnackKind.success,
        );
      }
    } on ApiException catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) {
        context.showSnack(e.localize(context), kind: SnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Admin reviewing the visit after the employee checked out — flip
  /// the lifecycle straight to `done` without going through the picker.
  /// Shown as its own prominent button when the visit is in
  /// `under_review`, since that's the single action the admin is on the
  /// screen to take.
  Future<void> _markAsDone() async {
    final visit = _visit;
    if (visit == null) return;
    setState(() => _busy = true);
    try {
      await sl<VisitsRepository>().update(visit.id, {'state': 'done'});
      HapticFeedback.mediumImpact();
      await _refreshFromServer();
      if (mounted) {
        context
            .read<VisitsListBloc>()
            .add(VisitsListLoadRequested(includeDrafts: _isManager));
        context.showSnack(
          context.s.visitDetailMarkAsDoneSuccess,
          kind: SnackKind.success,
        );
      }
    } on ApiException catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) {
        context.showSnack(e.localize(context), kind: SnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickEmployee() async {
    final repo = sl<EmployeesRepository>();
    final picked = await showPickerBottomSheet<Employee>(
      context: context,
      title: context.s.createVisitPickEmployee,
      searchHint: context.s.employeesSearchHint,
      loader: (q) => repo.list(search: q),
      itemBuilder: (ctx, e) => ListTile(
        leading: CircleAvatar(
          backgroundColor: ctx.colors.tertiaryContainer,
          child: Text(
            e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
            style: TextStyle(color: ctx.colors.onTertiaryContainer),
          ),
        ),
        title: Text(e.name),
        subtitle: e.login != null ? Text(e.login!) : null,
        onTap: () => Navigator.of(ctx).pop(e),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _editedEmployee = picked);
    }
  }
}

/// Map header behind the detail sheet (design 05/11/12). Shows the customer
/// office, the geofence ring, and check-in/out pins on a static map; falls
/// back to a brand-gradient panel when no coordinates are available.
class _MapHeader extends StatelessWidget {
  final Visit visit;
  const _MapHeader({required this.visit});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final center = visit.hasCustomerLocation
        ? LatLng(visit.customerLatitude!, visit.customerLongitude!)
        : (visit.hasCheckInLocation ? LatLng(visit.checkInLat!, visit.checkInLng!) : null);

    if (center == null) {
      return Container(
        decoration: BoxDecoration(gradient: x.brandGradient),
        alignment: Alignment.center,
        child: Icon(Symbols.business, fill: 1, size: 64,
            color: Colors.white.withValues(alpha: 0.85)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15.5,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E5E5),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.digitalharbor.location_gps',
              maxNativeZoom: 19,
            ),
            if (visit.hasCustomerLocation)
              CircleLayer(circles: [
                CircleMarker(
                  point: center,
                  radius: AppConstants.checkInRangeMeters,
                  useRadiusInMeter: true,
                  color: cs.primary.withValues(alpha: 0.12),
                  borderColor: cs.primary.withValues(alpha: 0.55),
                  borderStrokeWidth: 1.5,
                ),
              ]),
            MarkerLayer(markers: [
              if (visit.hasCustomerLocation)
                Marker(
                  point: center,
                  width: 44,
                  height: 44,
                  child: _Pin(icon: Symbols.business, gradient: x.avatarGradient),
                ),
              if (visit.hasCheckInLocation)
                Marker(
                  point: LatLng(visit.checkInLat!, visit.checkInLng!),
                  width: 34,
                  height: 34,
                  child: _Pin(icon: Symbols.login, color: x.success),
                ),
              if (visit.hasCheckOutLocation)
                Marker(
                  point: LatLng(visit.checkOutLat!, visit.checkOutLng!),
                  width: 34,
                  height: 34,
                  child: _Pin(icon: Symbols.logout, color: cs.error),
                ),
            ]),
          ],
        ),
        // Dark tint for dark theme readability.
        if (isDark)
          IgnorePointer(child: Container(color: Colors.black.withValues(alpha: 0.26))),
        // Bottom veil so the sheet edge blends into the map.
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [cs.surface.withValues(alpha: 0.55), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Gradient? gradient;
  const _Pin({required this.icon, this.color, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, fill: 1, size: 18, color: Colors.white),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? tint;
  const _FloatingChip({required this.icon, required this.onTap, this.tint});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.x.outlineVariant),
            boxShadow: context.x.elev2,
          ),
          child: Icon(icon, size: 20, color: tint ?? cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _CustomerBlock extends StatelessWidget {
  final Visit visit;
  const _CustomerBlock({required this.visit});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary,
                  Color.lerp(colors.primary, colors.tertiary, 0.55) ??
                      colors.primary,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.business_rounded,
                color: colors.onPrimary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.name ?? '#${visit.id}',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (visit.customerName != null)
                  Text(
                    visit.customerName!,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  final Visit visit;
  final bool canEdit;
  final DateTime? editedDate;
  final Customer? editedCustomer;
  final Employee? editedEmployee;
  final VisitLifecycleState? editedLifecycle;
  final VisitType? editedVisitType;
  final VoidCallback? onEditDate;
  final VoidCallback? onEditCustomer;
  final VoidCallback? onEditEmployee;
  final VoidCallback? onEditLifecycle;
  final VoidCallback? onEditVisitType;
  const _MetaBlock({
    required this.visit,
    required this.canEdit,
    required this.editedDate,
    required this.editedCustomer,
    required this.editedEmployee,
    required this.editedLifecycle,
    required this.editedVisitType,
    required this.onEditDate,
    required this.onEditCustomer,
    required this.onEditEmployee,
    required this.onEditLifecycle,
    required this.onEditVisitType,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final dateText = editedDate != null
        ? df.format(editedDate!)
        : (visit.visitDate != null
            ? df.format(visit.visitDate!)
            : (visit.checkInTime != null
                ? df.format(context.toUserTime(visit.checkInTime!))
                : '-'));
    final customerText = editedCustomer?.name ?? visit.customerName ?? '-';
    final employeeText = editedEmployee?.name ?? visit.employeeName ?? '-';
    final effectiveLifecycle = editedLifecycle ?? visit.lifecycleState;
    // -1 is the cleared sentinel; treat it as "no type".
    final effectiveVisitTypeName = editedVisitType != null
        ? (editedVisitType!.id == -1 ? null : editedVisitType!.name)
        : visit.visitTypeName;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: context.s.visitDetailMetaSection),
          const SizedBox(height: 6),
          _MetaRow(
            icon: Icons.event_outlined,
            label: context.s.visitDetailVisitDate,
            value: dateText,
            onEdit: canEdit ? onEditDate : null,
          ),
          if (canEdit || visit.customerName != null) ...[
            const Divider(height: 18),
            _MetaRow(
              icon: Icons.business_rounded,
              label: context.s.visitDetailCustomer,
              value: customerText,
              onEdit: canEdit ? onEditCustomer : null,
              editTooltip: context.s.visitDetailEditCustomer,
            ),
          ],
          if (canEdit || visit.employeeName != null) ...[
            const Divider(height: 18),
            _MetaRow(
              icon: Icons.person_outline,
              label: canEdit
                  ? context.s.visitDetailEmployee
                  : context.s.roleUser,
              value: employeeText,
              onEdit: canEdit ? onEditEmployee : null,
              editTooltip: context.s.visitDetailEditEmployee,
            ),
          ],
          if (canEdit || effectiveVisitTypeName != null) ...[
            const Divider(height: 18),
            _MetaRow(
              icon: Icons.label_outline_rounded,
              label: context.s.visitDetailVisitTypeLabel,
              value: effectiveVisitTypeName ?? '-',
              onEdit: canEdit ? onEditVisitType : null,
              editTooltip: context.s.visitDetailEditVisitType,
            ),
          ],
          if (canEdit) ...[
            const Divider(height: 18),
            _MetaRow(
              icon: Icons.flag_outlined,
              label: context.s.visitDetailStatusLabel,
              valueChild: _StateBadge(lifecycle: effectiveLifecycle),
              onEdit: onEditLifecycle,
              editTooltip: context.s.visitDetailEditState,
            ),
          ],
        ],
      ),
    );
  }
}

/// One row in `_MetaBlock` — icon + label on the left, value on the
/// right, with an optional edit pencil at the end when admin can tap.
class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueChild;
  final VoidCallback? onEdit;
  final String? editTooltip;
  const _MetaRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueChild,
    this.onEdit,
    this.editTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Flexible(
          child: valueChild ??
              Text(
                value ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
        ),
        if (onEdit != null)
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: editTooltip,
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
      ],
    );
  }
}

/// Admin-only status badge mapping `customer.visit.state` to a colored
/// pill (draft → grey, submit → blue, under_review → amber, done →
/// green, cancel → red).
class _StateBadge extends StatelessWidget {
  final VisitLifecycleState lifecycle;
  const _StateBadge({required this.lifecycle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, _) = switch (lifecycle) {
      VisitLifecycleState.draft => (colors.onSurfaceVariant, null),
      VisitLifecycleState.submit => (colors.primary, null),
      VisitLifecycleState.underReview => (Colors.amber.shade700, null),
      VisitLifecycleState.done => (Colors.green.shade600, null),
      VisitLifecycleState.cancel => (Colors.red.shade600, null),
      VisitLifecycleState.unknown => (colors.onSurfaceVariant, null),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        lifecycleStateLabel(context, lifecycle),
        style: context.text.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Manager-only block: full timestamps + employee coordinates +
/// range badges for both check-in and check-out, with placeholders
/// when the visit hasn't reached that stage yet.
class _AdminTimelineBlock extends StatelessWidget {
  final Visit visit;
  const _AdminTimelineBlock({required this.visit});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
              label: context.s.visitDetailTimelineLocationsSection),
          const SizedBox(height: 12),
          // Check-in section
          _TimelineEvent(
            icon: Icons.login_rounded,
            title: context.s.timelineCheckIn,
            time: visit.checkInTime,
            hasLocation: visit.hasCheckInLocation,
            lat: visit.checkInLat,
            lng: visit.checkInLng,
            range: visit.checkInState,
            placeholder: context.s.visitDetailNotStartedYet,
            mapLabel: context.s.visitDetailOpenCheckInLocation,
          ),
          const Divider(height: 22),
          // Check-out section
          _TimelineEvent(
            icon: Icons.logout_rounded,
            title: context.s.timelineCheckOut,
            time: visit.checkOutTime,
            hasLocation: visit.hasCheckOutLocation,
            lat: visit.checkOutLat,
            lng: visit.checkOutLng,
            range: visit.checkOutState,
            placeholder: context.s.visitDetailNotEndedYet,
            mapLabel: context.s.visitDetailOpenCheckOutLocation,
          ),
          if (visit.visitDuration != null) ...[
            const Divider(height: 22),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  context.s.timelineDuration(''),
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDuration(visit.visitDuration!),
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
          if (visit.executionDaysDelta != null) ...[
            const SizedBox(height: 10),
            _ExecutionDeltaRow(visit: visit),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _TimelineEvent extends StatelessWidget {
  final IconData icon;
  final String title;
  final DateTime? time;
  final bool hasLocation;
  final double? lat;
  final double? lng;
  final VisitRangeState range;
  final String placeholder;
  final String mapLabel;
  const _TimelineEvent({
    required this.icon,
    required this.title,
    required this.time,
    required this.hasLocation,
    required this.lat,
    required this.lng,
    required this.range,
    required this.placeholder,
    required this.mapLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasTime = time != null;
    final fmt = DateFormat('yyyy-MM-dd  HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: context.text.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (range == VisitRangeState.inRange ||
                range == VisitRangeState.notInRange)
              _RangePill(state: range),
          ],
        ),
        const SizedBox(height: 6),
        if (!hasTime)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              placeholder,
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              fmt.format(context.toUserTime(time!)),
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (hasLocation) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: Text(mapLabel),
              onPressed: () =>
                  Communications.openInMaps(lat!, lng!),
            ),
          ],
        ],
      ],
    );
  }
}

/// Red banner at the top of the admin's detail view when the scheduled
/// day has passed and the visit isn't done yet. Spells out the action
/// the admin should take (reschedule or follow up).
class _OverdueBanner extends StatelessWidget {
  final Visit visit;
  const _OverdueBanner({required this.visit});

  @override
  Widget build(BuildContext context) {
    final color = Colors.red.shade600;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.s.visitDetailOverdueHint,
              style: context.text.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single row inside the admin timeline that says, for completed
/// visits, whether they ran on time / earlier / later than scheduled.
class _ExecutionDeltaRow extends StatelessWidget {
  final Visit visit;
  const _ExecutionDeltaRow({required this.visit});

  @override
  Widget build(BuildContext context) {
    final delta = visit.executionDaysDelta;
    if (delta == null) return const SizedBox.shrink();
    final colors = context.colors;
    final (color, icon, text) = switch (delta.compareTo(0)) {
      < 0 => (
        Colors.green.shade600,
        Icons.fast_rewind_rounded,
        context.s.visitExecutedEarly(-delta),
      ),
      > 0 => (
        Colors.amber.shade700,
        Icons.fast_forward_rounded,
        context.s.visitExecutedLate(delta),
      ),
      _ => (
        colors.primary,
        Icons.check_circle_outline,
        context.s.visitExecutedOnTime,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  final VisitRangeState state;
  const _RangePill({required this.state});

  @override
  Widget build(BuildContext context) {
    final inRange = state == VisitRangeState.inRange;
    final color = inRange ? Colors.green.shade600 : Colors.red.shade600;
    final label = inRange
        ? context.s.visitRangeInRange
        : context.s.visitRangeOutOfRange;
    final icon =
        inRange ? Icons.check_circle_outline : Icons.error_outline_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Manager-only block: customer address + phone + a single Navigate
/// button. Shown on the detail page so the admin can call the customer
/// or jump straight to their map location.
class _CustomerLocationBlock extends StatelessWidget {
  final Visit visit;
  const _CustomerLocationBlock({required this.visit});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final address = visit.customerAddress?.trim();
    final phone = visit.customerPhone?.trim();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: context.s.visitDetailCustomerLocationSection),
          const SizedBox(height: 10),
          if (address != null && address.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined,
                    size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium,
                  ),
                ),
              ],
            ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone_outlined,
                    size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(phone, style: context.text.bodyMedium),
                ),
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  tooltip: context.s.customerActionCall,
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => Communications.dial(phone),
                ),
              ],
            ),
          ],
          if (visit.hasCustomerLocation) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: Text(context.s.visitDetailNavigate),
                onPressed: () => Communications.openInMaps(
                  visit.customerLatitude!,
                  visit.customerLongitude!,
                  label: visit.customerName,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  final Visit visit;
  const _TimelineBlock({required this.visit});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: context.s.visitDetailTimelineSection),
          const SizedBox(height: 8),
          if (visit.checkInTime != null)
            InfoRow(
              icon: Icons.login_rounded,
              text:
                  '${context.s.timelineCheckIn}: ${fmt.format(context.toUserTime(visit.checkInTime!))}',
            ),
          if (visit.checkOutTime != null) ...[
            const SizedBox(height: 4),
            InfoRow(
              icon: Icons.logout_rounded,
              text:
                  '${context.s.timelineCheckOut}: ${fmt.format(context.toUserTime(visit.checkOutTime!))}',
            ),
          ],
          if (visit.durationMinutes != null) ...[
            const SizedBox(height: 4),
            InfoRow(
              icon: Icons.schedule_rounded,
              text: context.s.timelineDuration(
                  visit.durationMinutes!.toString()),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotesBlock extends StatelessWidget {
  final Visit visit;
  final TextEditingController controller;
  final bool editable;
  final bool editing;
  final VoidCallback? onEditToggle;
  const _NotesBlock({
    required this.visit,
    required this.controller,
    required this.editable,
    required this.editing,
    required this.onEditToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionLabel(label: context.s.visitDetailNotesSection),
              const Spacer(),
              if (editable)
                TextButton.icon(
                  onPressed: onEditToggle,
                  icon: Icon(editing
                      ? Icons.check_circle_outline
                      : Icons.edit_outlined),
                  label: Text(editing
                      ? context.s.commonClose
                      : context.s.visitDetailEditNotes),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (editing)
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: context.s.visitNotesLabel,
              ),
            )
          else if ((visit.description ?? '').trim().isEmpty)
            Text(
              context.s.visitDetailNoNotes,
              style: context.text.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Text(
              visit.description!,
              style: context.text.bodyMedium,
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: context.text.labelSmall?.copyWith(
        color: context.colors.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}

/// Shimmer placeholder shown on the detail page while data is in
/// flight — either on first open (no `initial`) or while the admin
/// pull-to-refreshes. Mirrors the rough shape of the real layout
/// (customer header + meta + timeline + notes) so the swap feels
/// stable rather than collapsing the page height.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          SkeletonCard(height: 80),
          SizedBox(height: 14),
          SkeletonCard(height: 180),
          SizedBox(height: 14),
          SkeletonCard(height: 140),
          SizedBox(height: 14),
          SkeletonCard(height: 110),
          SizedBox(height: 14),
          SkeletonCard(height: 90),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  final String text;
  const _HintRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 14, color: context.colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

