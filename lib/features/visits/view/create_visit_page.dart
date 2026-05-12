import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../customers/data/customers_repository.dart';
import '../../customers/data/models/customer.dart';
import '../../employees/data/employees_repository.dart';
import '../../employees/data/models/employee.dart';
import '../bloc/create_visit_bloc.dart';
import '../bloc/visits_list_bloc.dart';
import '../data/models/visit_type.dart';
import '../data/visits_repository.dart';

/// Manager-only form to create a new `customer.visit` (state=draft).
///
/// Pre-fills the employee (or customer) when launched from the Employees /
/// Customers tab with `extra: {'employee': Employee}` or
/// `extra: {'customer': Customer}`.
class CreateVisitPage extends StatelessWidget {
  final Customer? preselectedCustomer;
  final Employee? preselectedEmployee;

  const CreateVisitPage({
    super.key,
    this.preselectedCustomer,
    this.preselectedEmployee,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = CreateVisitBloc(repository: sl<VisitsRepository>());
        if (preselectedCustomer != null) {
          bloc.add(CreateVisitCustomerSelected(preselectedCustomer!));
        }
        if (preselectedEmployee != null) {
          bloc.add(CreateVisitEmployeeSelected(preselectedEmployee!));
        }
        bloc.add(CreateVisitDateSelected(_today()));
        return bloc;
      },
      child: const _CreateVisitView(),
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class _CreateVisitView extends StatelessWidget {
  const _CreateVisitView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateVisitBloc, CreateVisitState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == CreateVisitStatus.success) {
          HapticFeedback.mediumImpact();
          context.showSnack(context.s.createVisitSuccess);
          // Refresh the visits list so the new draft appears immediately.
          context.read<VisitsListBloc>().add(const VisitsListLoadRequested());
          if (context.canPop()) context.pop();
        } else if (state.status == CreateVisitStatus.failure &&
            state.error != null) {
          HapticFeedback.lightImpact();
          context.showSnack(state.error!.localize(context));
        }
      },
      builder: (context, state) {
        final submitting = state.status == CreateVisitStatus.submitting;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.s.createVisitTitle),
            actions: [
              TextButton(
                onPressed: (state.isValid && !submitting)
                    ? () => context
                        .read<CreateVisitBloc>()
                        .add(const CreateVisitSubmitted())
                    : null,
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Text(context.s.createVisitSubmit),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: AbsorbPointer(
            absorbing: submitting,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: const [
                _CustomerField(),
                SizedBox(height: 12),
                _EmployeeField(),
                SizedBox(height: 12),
                _DateField(),
                SizedBox(height: 12),
                _TypeField(),
                SizedBox(height: 12),
                _NotesField(),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppButton(
                label: context.s.createVisitSubmit,
                icon: Icons.check_circle_outline,
                loading: submitting,
                onPressed: state.isValid
                    ? () => context
                        .read<CreateVisitBloc>()
                        .add(const CreateVisitSubmitted())
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CustomerField extends StatelessWidget {
  const _CustomerField();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVisitBloc, CreateVisitState>(
      buildWhen: (p, c) => p.customer != c.customer,
      builder: (context, state) => _FieldRow(
        icon: Icons.business_rounded,
        label: context.s.createVisitCustomerLabel,
        value: state.customer?.name,
        placeholder: context.s.createVisitPickCustomer,
        onTap: () async {
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
          if (picked != null && context.mounted) {
            context
                .read<CreateVisitBloc>()
                .add(CreateVisitCustomerSelected(picked));
          }
        },
      ),
    );
  }
}

class _EmployeeField extends StatelessWidget {
  const _EmployeeField();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVisitBloc, CreateVisitState>(
      buildWhen: (p, c) => p.employee != c.employee,
      builder: (context, state) => _FieldRow(
        icon: Icons.person_outline,
        label: context.s.createVisitEmployeeLabel,
        value: state.employee?.name,
        placeholder: context.s.createVisitPickEmployee,
        onTap: () async {
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
          if (picked != null && context.mounted) {
            context
                .read<CreateVisitBloc>()
                .add(CreateVisitEmployeeSelected(picked));
          }
        },
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField();

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    return BlocBuilder<CreateVisitBloc, CreateVisitState>(
      buildWhen: (p, c) => p.date != c.date,
      builder: (context, state) => _FieldRow(
        icon: Icons.event_outlined,
        label: context.s.createVisitDateLabel,
        value: state.date != null ? fmt.format(state.date!) : null,
        placeholder: context.s.createVisitDateRequired,
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: state.date ?? now,
            firstDate: now.subtract(const Duration(days: 2)),
            lastDate: now.add(const Duration(days: 365)),
          );
          if (picked != null && context.mounted) {
            context
                .read<CreateVisitBloc>()
                .add(CreateVisitDateSelected(picked));
          }
        },
      ),
    );
  }
}

class _TypeField extends StatelessWidget {
  const _TypeField();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateVisitBloc, CreateVisitState>(
      buildWhen: (p, c) =>
          p.visitTypeId != c.visitTypeId || p.visitTypeName != c.visitTypeName,
      builder: (context, state) => _FieldRow(
        icon: Icons.label_outline_rounded,
        label: context.s.createVisitTypeLabel,
        value: state.visitTypeName,
        placeholder: context.s.createVisitPickType,
        trailing: state.visitTypeId != null
            ? IconButton(
                tooltip: context.s.commonClose,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => context
                    .read<CreateVisitBloc>()
                    .add(const CreateVisitTypeSelected()),
              )
            : null,
        onTap: () async {
          final repo = sl<VisitsRepository>();
          final picked = await showPickerBottomSheet<VisitType>(
            context: context,
            title: context.s.createVisitPickType,
            searchHint: context.s.pickerSearchHint,
            loader: (q) async {
              final all = await repo.listVisitTypes();
              if (q == null || q.isEmpty) return all;
              final lc = q.toLowerCase();
              return all
                  .where((t) => t.name.toLowerCase().contains(lc))
                  .toList();
            },
            itemBuilder: (ctx, t) => ListTile(
              leading: const Icon(Icons.label_outline_rounded),
              title: Text(t.name),
              onTap: () => Navigator.of(ctx).pop(t),
            ),
          );
          if (picked != null && context.mounted) {
            context.read<CreateVisitBloc>().add(
                  CreateVisitTypeSelected(id: picked.id, name: picked.name),
                );
          }
        },
      ),
    );
  }
}

class _NotesField extends StatefulWidget {
  const _NotesField();
  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: context.read<CreateVisitBloc>().state.notes);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded,
                  size: 18, color: context.colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                context.s.createVisitNotesLabel,
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: context.s.visitNotesLabel,
            ),
            onChanged: (v) => context
                .read<CreateVisitBloc>()
                .add(CreateVisitNotesChanged(v)),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final Widget? trailing;

  const _FieldRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Icon(icon,
                  size: 22, color: context.colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasValue ? value! : placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        color: hasValue
                            ? context.colors.onSurface
                            : context.colors.onSurfaceVariant,
                        fontWeight:
                            hasValue ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              Icon(Icons.chevron_right,
                  color: context.colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
