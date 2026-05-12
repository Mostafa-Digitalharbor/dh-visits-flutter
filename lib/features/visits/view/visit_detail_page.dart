import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/location/location_service.dart';
import '../../../core/utils/user_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/visit_bloc.dart';
import '../bloc/visits_list_bloc.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';

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
  late TextEditingController _notesCtrl;

  bool _editingNotes = false;
  DateTime? _editedVisitDate;

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

  Future<void> _refreshFromServer() async {
    try {
      final list = await sl<VisitsRepository>().list();
      final fresh = list.firstWhere(
        (v) => v.id == widget.visitId,
        orElse: () => _visit ?? Visit(id: widget.visitId),
      );
      if (mounted) setState(() => _visit = fresh);
    } on ApiException catch (e) {
      if (mounted) context.showSnack(e.localize(context));
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
      await sl<VisitsRepository>().update(visit.id, {
        'state': 'submit',
        'check_in_date_time': _odooDateFmt.format(nowUtc),
        'check_in_lat': pos.latitude,
        'check_in_lng': pos.longitude,
      });
      HapticFeedback.mediumImpact();
      final customerName = visit.customerName;
      await _refreshFromServer();
      if (mounted) {
        // Refresh the surrounding list + tell VisitBloc to re-pick the
        // active visit so the home shell switches to the persistent bar.
        context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
        context.read<VisitBloc>().add(const VisitResumeRequested());
        context.showSnack(customerName != null && customerName.isNotEmpty
            ? context.s.visitDetailCheckInStartedAt(customerName)
            : context.s.checkInSuccess);
      }
    } on ApiException catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) context.showSnack(e.localize(context));
    } catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) context.showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut() async {
    final visit = _visit;
    if (visit == null) return;
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
      if (_notesCtrl.text.trim().isNotEmpty) {
        payload['description'] = _notesCtrl.text.trim();
      }
      await sl<VisitsRepository>().update(visit.id, payload);
      HapticFeedback.mediumImpact();
      await _refreshFromServer();
      if (mounted) {
        context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
        context.read<VisitBloc>().add(const VisitCleared());
        context.showSnack(context.s.checkOutSuccess);
      }
    } on ApiException catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) context.showSnack(e.localize(context));
    } catch (e) {
      HapticFeedback.lightImpact();
      if (mounted) context.showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
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
    if (payload.isEmpty) return;
    setState(() => _busy = true);
    try {
      await sl<VisitsRepository>().update(visit.id, payload);
      HapticFeedback.lightImpact();
      await _refreshFromServer();
      if (mounted) {
        context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
        context.showSnack(context.s.visitDetailSaved);
        setState(() {
          _editingNotes = false;
          _editedVisitDate = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) context.showSnack(e.localize(context));
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isActive = visit.state == VisitStateType.checkedIn;
    final isCompleted = visit.state == VisitStateType.checkedOut;
    final canCheckIn =
        !isActive && !isCompleted && visit.checkInTime == null;
    final notesEditableByUser = isActive; // user can write notes mid-visit
    final notesEditable = canEdit || notesEditableByUser;

    // Keep the controller in sync when not actively editing.
    if (!_editingNotes) {
      _notesCtrl.text = visit.description ?? '';
    }

    final showSave = _editingNotes || (canEdit && _editedVisitDate != null);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.s.visitDetailTitle),
        actions: [
          if (showSave)
            TextButton(
              onPressed: _busy ? null : _saveEdits,
              child: Text(context.s.visitDetailSaveChanges),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFromServer,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _CustomerBlock(visit: visit),
            const SizedBox(height: 14),
            _MetaBlock(
              visit: visit,
              canEdit: canEdit,
              editedDate: _editedVisitDate,
              onEditDate: canEdit
                  ? () async {
                      final initial = _editedVisitDate ??
                          DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null && mounted) {
                        setState(() => _editedVisitDate = picked);
                      }
                    }
                  : null,
            ),
            if (visit.checkInTime != null) ...[
              const SizedBox(height: 14),
              _TimelineBlock(visit: visit),
            ],
            const SizedBox(height: 14),
            _NotesBlock(
              visit: visit,
              controller: _notesCtrl,
              editable: notesEditable,
              editing: _editingNotes,
              onEditToggle: notesEditable
                  ? () => setState(() => _editingNotes = !_editingNotes)
                  : null,
            ),
            const SizedBox(height: 8),
            if (!canEdit && !notesEditableByUser)
              _HintRow(text: context.s.visitDetailReadOnlyHint),
            if (notesEditableByUser && !canEdit)
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
  final VoidCallback? onEditDate;
  const _MetaBlock({
    required this.visit,
    required this.canEdit,
    required this.editedDate,
    required this.onEditDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final df = DateFormat('yyyy-MM-dd');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: context.s.visitDetailMetaSection),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event_outlined,
                  size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(context.s.visitDetailVisitDate,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  )),
              const Spacer(),
              Text(
                editedDate != null
                    ? df.format(editedDate!)
                    : (visit.checkInTime != null
                        ? df.format(context.toUserTime(visit.checkInTime!))
                        : '-'),
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (canEdit)
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEditDate,
                ),
            ],
          ),
          if (visit.employeeName != null) ...[
            const Divider(height: 18),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(context.s.roleUser,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    )),
                const Spacer(),
                Text(
                  visit.employeeName!,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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

