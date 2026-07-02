import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
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

  @override
  Widget build(BuildContext context) {
    final canPlanForOthers =
        context.read<AuthBloc>().state.user?.canPlanForOthers ?? false;

    return BlocConsumer<CreateVisitBloc, CreateVisitState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == CreateVisitStatus.success) {
          context.showSnack(context.s.wfCreated, kind: SnackKind.success);
          // Refresh the list if it's provided app-wide, then leave.
          try {
            context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
          } catch (_) {}
          final id = state.createdVisitId;
          if (id != null) {
            context.go('/visits/$id');
          } else {
            context.pop();
          }
        } else if (state.status == CreateVisitStatus.failure &&
            state.error != null) {
          context.showSnack(state.error!.localize(context),
              kind: SnackKind.error);
        }
      },
      builder: (context, state) {
        final bloc = context.read<CreateVisitBloc>();
        return Scaffold(
          appBar: AppBar(title: Text(context.s.wfCreateTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Visit type
              Text(context.s.wfFieldType, style: context.text.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<VisitType>(
                segments: [
                  ButtonSegment(
                    value: VisitType.project,
                    label: Text(context.s.wfTypeProject),
                    icon: const Icon(Icons.folder_open_outlined),
                  ),
                  ButtonSegment(
                    value: VisitType.opportunity,
                    label: Text(context.s.wfTypeOpportunity),
                    icon: const Icon(Icons.emoji_events_outlined),
                  ),
                ],
                selected: {state.visitType},
                onSelectionChanged: (s) =>
                    bloc.add(CreateVisitTypeChanged(s.first)),
              ),
              const SizedBox(height: 16),

              // Linked project/opportunity
              _PickerTile(
                label: state.visitType == VisitType.project
                    ? context.s.wfFieldProject
                    : context.s.wfFieldOpportunity,
                value: state.linked?.name,
                icon: Icons.link,
                onTap: () => _pickLinked(context, bloc, state.visitType),
              ),
              if (state.customerName != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.business,
                          size: 15, color: context.colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${context.s.wfFieldCustomer}: ${state.customerName}',
                          style: context.text.bodySmall),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Schedule
              _PickerTile(
                label: context.s.wfFieldSchedule,
                value: state.scheduled != null
                    ? DateFormat('EEE, MMM d • HH:mm').format(state.scheduled!)
                    : null,
                icon: Icons.event,
                onTap: () => _pickSchedule(context, bloc, state.scheduled),
              ),
              const SizedBox(height: 12),

              // Purpose (required)
              TextField(
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.s.wfFieldPurpose,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => bloc.add(CreateVisitPurposeChanged(v)),
              ),
              const SizedBox(height: 12),

              // Location
              TextField(
                decoration: InputDecoration(
                  labelText:
                      '${context.s.wfFieldLocation} ${context.s.commonOptional}',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => bloc.add(CreateVisitLocationChanged(v)),
              ),

              if (canPlanForOthers) ...[
                const SizedBox(height: 12),
                _PickerTile(
                  label:
                      '${context.s.wfFieldResponsible} ${context.s.commonOptional}',
                  value: state.employee?.name ?? context.s.wfSelfLabel,
                  icon: Icons.person_outline,
                  onTap: () => _pickEmployee(context, bloc),
                ),
                const SizedBox(height: 12),
                _ParticipantsField(state: state, bloc: bloc),
              ],

              const SizedBox(height: 24),
              AppButton(
                label: context.s.createVisitSubmit,
                icon: Icons.check,
                loading: state.status == CreateVisitStatus.submitting,
                onPressed: state.isValid
                    ? () => bloc.add(const CreateVisitSubmitted())
                    : null,
              ),
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
    final selected = await showPickerBottomSheet<LinkedRecord>(
      context: context,
      title: type == VisitType.project
          ? context.s.wfPickProject
          : context.s.wfPickOpportunity,
      searchHint: context.s.commonSearch,
      loader: (search) async {
        final all = type == VisitType.project
            ? await repo.listProjects()
            : await repo.listOpportunities();
        if (search == null || search.isEmpty) return all;
        final q = search.toLowerCase();
        return all.where((e) => e.name.toLowerCase().contains(q)).toList();
      },
      itemBuilder: (ctx, r) => ListTile(
        title: Text(r.name),
        subtitle: r.partnerName != null ? Text(r.partnerName!) : null,
        onTap: () => Navigator.of(ctx).pop(r),
      ),
    );
    if (selected != null) bloc.add(CreateVisitLinkedSelected(selected));
  }

  Future<void> _pickSchedule(
    BuildContext context,
    CreateVisitBloc bloc,
    DateTime? current,
  ) async {
    final now = DateTime.now();
    final base = current ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    final t = time ?? TimeOfDay.fromDateTime(base);
    bloc.add(CreateVisitScheduleSelected(
      DateTime(date.year, date.month, date.day, t.hour, t.minute),
    ));
  }

  Future<void> _pickEmployee(
    BuildContext context,
    CreateVisitBloc bloc,
  ) async {
    final selected = await showPickerBottomSheet<Employee>(
      context: context,
      title: context.s.wfPickEmployee,
      searchHint: context.s.employeesSearchHint,
      loader: (search) => sl<EmployeesRepository>().list(search: search),
      itemBuilder: (ctx, e) => ListTile(
        title: Text(e.name),
        subtitle: e.login != null ? Text(e.login!) : null,
        onTap: () => Navigator.of(ctx).pop(e),
      ),
    );
    if (selected != null) bloc.add(CreateVisitEmployeeSelected(selected));
  }
}

class _ParticipantsField extends StatelessWidget {
  final CreateVisitState state;
  final CreateVisitBloc bloc;
  const _ParticipantsField({required this.state, required this.bloc});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(context.s.wfFieldParticipants,
                  style: context.text.labelLarge),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.s.wfActionAddParticipant),
              onPressed: () async {
                final e = await showPickerBottomSheet<Employee>(
                  context: context,
                  title: context.s.wfPickEmployee,
                  searchHint: context.s.employeesSearchHint,
                  loader: (search) async {
                    final list =
                        await sl<EmployeesRepository>().list(search: search);
                    return list.where((e) => e.hrEmployeeId != null).toList();
                  },
                  itemBuilder: (ctx, e) => ListTile(
                    title: Text(e.name),
                    onTap: () => Navigator.of(ctx).pop(e),
                  ),
                );
                if (e != null) bloc.add(CreateVisitParticipantAdded(e));
              },
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in state.participants)
              Chip(
                label: Text(p.name),
                onDeleted: () => bloc.add(CreateVisitParticipantRemoved(p)),
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
  final VoidCallback onTap;
  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label, style: context.text.labelMedium),
        subtitle: Text(
          value ?? context.s.commonRequired,
          style: context.text.bodyLarge?.copyWith(
            color: value == null ? context.colors.outline : null,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
