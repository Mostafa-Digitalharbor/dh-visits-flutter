import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../app/routes.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/app_date.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/picker_bottom_sheet.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../employees/data/employees_repository.dart';
import '../../employees/data/models/employee.dart';
import '../bloc/create_visit_bloc.dart';
import '../bloc/visits_list_bloc.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';
import 'visit_schedule_picker.dart';

class CreateVisitPage extends StatelessWidget {
  final Employee? preselectedEmployee;
  const CreateVisitPage({super.key, this.preselectedEmployee});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = CreateVisitBloc(repository: sl<VisitsRepository>());
        if (preselectedEmployee != null) {
          bloc.add(CreateVisitEmployeeSelected(preselectedEmployee));
        }
        return bloc;
      },
      child: const _CreateVisitView(),
    );
  }
}

class _CreateVisitView extends StatelessWidget {
  const _CreateVisitView();

  /// The purpose field opens two lines tall and grows to four before it
  /// scrolls: a sentence or two is the usual answer.
  static const int _purposeMinLines = 2;
  static const int _purposeMaxLines = 4;

  void _onStatus(BuildContext context, CreateVisitState state) {
    final s = context.s;
    final createdId = state.createdVisitId;
    switch (state.status) {
      case CreateVisitStatus.success:
        context.showSnack(s.wfCreated, kind: SnackKind.success);
        context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
        if (createdId != null) {
          context.go(AppRoutes.visitDetail(createdId));
        } else {
          context.pop();
        }
      case CreateVisitStatus.failure:
        final error = state.error;
        if (error == null) return;
        final reason = error.localize(context);
        context.showSnack(
          // The visit exists — say so, or the user retries a creation that
          // already happened.
          state.isCreated ? s.wfParticipantsNotAdded(reason) : reason,
          kind: SnackKind.error,
        );
        if (state.isCreated) {
          // It exists on the server now, so the list should show it.
          context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
        }
      case CreateVisitStatus.idle:
      case CreateVisitStatus.submitting:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPlanForOthers =
        context.read<AuthBloc>().state.user?.canPlanForOthers ?? false;

    return BlocConsumer<CreateVisitBloc, CreateVisitState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: _onStatus,
      builder: (context, state) {
        final s = context.s;
        final bloc = context.read<CreateVisitBloc>();
        final submitting = state.status == CreateVisitStatus.submitting;
        // Once the visit exists only its participants may still change; see
        // CreateVisitState.createdVisitId.
        final editable = !state.isCreated && !submitting;
        final createdId = state.createdVisitId;
        final customer = state.customerName;
        final scheduled = state.scheduled;
        return Scaffold(
          appBar: AppBar(title: Text(s.wfCreateTitle)),
          body: ListView(
            padding: context.padAll(Insets.screen),
            children: [
              // Visit type
              Text(s.wfFieldType, style: context.text.labelLarge),
              context.gapH(Insets.x1h),
              SegmentedButton<VisitType>(
                segments: [
                  ButtonSegment(
                    value: VisitType.project,
                    label: Text(s.wfTypeProject),
                    icon: const Icon(Icons.folder_open_outlined),
                  ),
                  ButtonSegment(
                    value: VisitType.opportunity,
                    label: Text(s.wfTypeOpportunity),
                    icon: const Icon(Icons.emoji_events_outlined),
                  ),
                ],
                selected: {state.visitType},
                onSelectionChanged: editable
                    ? (types) => bloc.add(CreateVisitTypeChanged(types.first))
                    : null,
              ),
              context.gapH(Insets.x4),

              // Linked project/opportunity
              _PickerTile(
                label: state.visitType == VisitType.project
                    ? s.wfFieldProject
                    : s.wfFieldOpportunity,
                value: state.linked?.name,
                icon: Icons.link,
                onTap: editable
                    ? () => _pickLinked(context, bloc, state.visitType)
                    : null,
              ),
              if (customer != null)
                Padding(
                  // Directional: this indents under the picker tile above it,
                  // so in Arabic it must indent from the start edge too.
                  padding: EdgeInsetsDirectional.only(
                    start: context.r(Insets.x3),
                    top: context.r(Insets.hair),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: context.r(IconSz.pill),
                        color: context.colors.onSurfaceVariant,
                      ),
                      context.gapW(Insets.x1),
                      // Expanded + ellipsis: the customer auto-fills from the
                      // linked project/opportunity and Odoo company names run
                      // long (more so in Arabic) — unbounded it overflows the
                      // row.
                      Expanded(
                        child: Text(
                          s.wfLinkedCustomer(customer),
                          style: context.text.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              context.gapH(Insets.x3),

              // Schedule
              _PickerTile(
                label: s.wfFieldSchedule,
                value: scheduled != null
                    ? AppDate.weekdayDateTime(context, scheduled)
                    : null,
                icon: Icons.event,
                onTap: editable
                    ? () => _pickSchedule(context, bloc, scheduled)
                    : null,
              ),
              context.gapH(Insets.x3),

              // Purpose (required)
              TextField(
                enabled: editable,
                minLines: _purposeMinLines,
                maxLines: _purposeMaxLines,
                decoration: InputDecoration(
                  labelText: s.wfFieldPurpose,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => bloc.add(CreateVisitPurposeChanged(v)),
              ),
              context.gapH(Insets.x3),

              // Location
              TextField(
                enabled: editable,
                decoration: InputDecoration(
                  labelText: s.wfOptionalField(s.wfFieldLocation),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => bloc.add(CreateVisitLocationChanged(v)),
              ),

              if (canPlanForOthers) ...[
                context.gapH(Insets.x3),
                _PickerTile(
                  label: s.wfOptionalField(s.wfFieldResponsible),
                  value: state.employee?.name ?? s.wfSelfLabel,
                  icon: Icons.person_outline,
                  onTap: editable ? () => _pickEmployee(context, bloc) : null,
                  // The way back to "myself" once someone else was picked.
                  trailing: editable && state.employee != null
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: s.wfPlanForMyself,
                          onPressed: () =>
                              bloc.add(const CreateVisitEmployeeSelected(null)),
                        )
                      : null,
                ),
                context.gapH(Insets.x3),
                _ParticipantsField(state: state, bloc: bloc),
              ],

              context.gapH(Insets.x6),
              AppButton(
                label: state.isCreated
                    ? s.wfRetryAddParticipants
                    : s.createVisitSubmit,
                icon: state.isCreated ? Icons.group_add_outlined : Icons.check,
                loading: submitting,
                onPressed: state.isValid
                    ? () => bloc.add(const CreateVisitSubmitted())
                    : null,
              ),
              if (createdId != null && !submitting) ...[
                context.gapH(Insets.x2),
                AppButton.secondary(
                  label: s.wfOpenCreatedVisit,
                  icon: Icons.open_in_new,
                  onPressed: () => context.go(AppRoutes.visitDetail(createdId)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickLinked(
    BuildContext context,
    CreateVisitBloc bloc,
    VisitType type,
  ) async {
    final repo = sl<VisitsRepository>();
    final s = context.s;
    final selected = await showPickerBottomSheet<LinkedRecord>(
      context: context,
      title: type == VisitType.project ? s.wfPickProject : s.wfPickOpportunity,
      searchHint: s.commonSearch,
      // Searched on the server, so a record beyond the first page is still
      // reachable by name.
      loader: (search) => type == VisitType.project
          ? repo.listProjects(search: search)
          : repo.listOpportunities(search: search),
      itemBuilder: (ctx, r) {
        final partner = r.partnerName;
        return ListTile(
          title: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: partner != null
              ? Text(partner, maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          onTap: () => Navigator.of(ctx).pop(r),
        );
      },
    );
    if (selected != null && !bloc.isClosed) {
      bloc.add(CreateVisitLinkedSelected(selected));
    }
  }

  Future<void> _pickSchedule(
    BuildContext context,
    CreateVisitBloc bloc,
    DateTime? current,
  ) async {
    final picked = await pickVisitSchedule(context, current: current);
    if (picked != null && !bloc.isClosed) {
      bloc.add(CreateVisitScheduleSelected(picked));
    }
  }

  Future<void> _pickEmployee(BuildContext context, CreateVisitBloc bloc) async {
    final s = context.s;
    final selected = await showPickerBottomSheet<Employee>(
      context: context,
      title: s.wfPickEmployee,
      searchHint: s.employeesSearchHint,
      loader: (search) => sl<EmployeesRepository>().list(search: search),
      itemBuilder: (ctx, e) {
        final login = e.login;
        return ListTile(
          title: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: login != null
              ? Text(login, maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          onTap: () => Navigator.of(ctx).pop(e),
        );
      },
    );
    if (selected != null && !bloc.isClosed) {
      bloc.add(CreateVisitEmployeeSelected(selected));
    }
  }
}

class _ParticipantsField extends StatelessWidget {
  final CreateVisitState state;
  final CreateVisitBloc bloc;
  const _ParticipantsField({required this.state, required this.bloc});

  Future<void> _add(BuildContext context) async {
    final s = context.s;
    final chosen = {for (final p in state.participants) p.hrEmployeeId};
    final employee = await showPickerBottomSheet<Employee>(
      context: context,
      title: s.wfPickEmployee,
      searchHint: s.employeesSearchHint,
      loader: (search) async {
        final list = await sl<EmployeesRepository>().list(search: search);
        // Only people who can be added, and not twice.
        return list
            .where(
              (e) => e.hrEmployeeId != null && !chosen.contains(e.hrEmployeeId),
            )
            .toList();
      },
      itemBuilder: (ctx, e) => ListTile(
        title: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => Navigator.of(ctx).pop(e),
      ),
    );
    if (employee != null && !bloc.isClosed) {
      bloc.add(CreateVisitParticipantAdded(employee));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final busy = state.status == CreateVisitStatus.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.wfFieldParticipants,
                style: context.text.labelLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: TextButton.icon(
                icon: Icon(Icons.add, size: context.r(IconSz.label)),
                label: Text(
                  s.wfActionAddParticipant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: busy ? null : () => _add(context),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: context.r(Insets.x1h),
          runSpacing: context.r(Insets.x1h),
          children: [
            for (final p in state.participants)
              Chip(
                label: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onDeleted: busy
                    ? null
                    : () => bloc.add(CreateVisitParticipantRemoved(p)),
              ),
          ],
        ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;

  /// Null disables the tile (the visit already exists).
  final VoidCallback? onTap;

  /// Replaces the chevron — the responsible-employee tile's "clear" button.
  final Widget? trailing;

  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        enabled: onTap != null,
        leading: Icon(icon),
        title: Text(
          label,
          style: context.text.labelMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          value ?? context.s.commonRequired,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyLarge?.copyWith(
            color: value == null ? context.colors.outline : null,
          ),
        ),
        // Not `isRtl ? chevron_left : chevron_right`: both icons are declared
        // `matchTextDirection: true`, so the framework already mirrors them.
        // Picking chevron_left for Arabic flipped it a second time and the
        // chevron pointed back out of the screen it opens. Same reasoning as
        // [VisitDetailRow].
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
