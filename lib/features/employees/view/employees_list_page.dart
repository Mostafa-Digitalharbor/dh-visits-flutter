
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../bloc/employees_bloc.dart';
import '../data/models/employee.dart';
import '../../../shared/bloc/searchable_list_bloc.dart';

/// Manager-only screen: lists `res.users` in the Customer Visits groups.
/// Each row has a quick "+ visit" action that jumps to the create form
/// with this employee pre-selected.
class EmployeesListPage extends StatefulWidget {
  const EmployeesListPage({super.key});

  @override
  State<EmployeesListPage> createState() => _EmployeesListPageState();
}

class _EmployeesListPageState extends State<EmployeesListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EmployeesBloc>().add(const ListLoadRequested());
    });
  }

  Future<void> _refresh() async {
    context.read<EmployeesBloc>().add(const ListLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DebouncedSearchField(
          hintText: context.s.employeesSearchHint,
          onChanged: (q) =>
              context.read<EmployeesBloc>().add(ListSearchChanged(q)),
        ),
        Expanded(
          // Listener as well as builder: a refresh that fails while rows are
          // already on screen never reaches the error view, and would
          // otherwise pass in complete silence.
          child: BlocConsumer<EmployeesBloc, EmployeesState>(
            listenWhen: (prev, curr) =>
                prev.status != curr.status &&
                curr.hasError &&
                curr.items.isNotEmpty,
            listener: (context, state) => context.showSnack(
              state.error?.localize(context) ?? context.s.errUnknown,
              kind: SnackKind.error,
            ),
            builder: (context, state) => AsyncListView<Employee>(
              items: state.items,
              isLoading: state.isLoading,
              hasError: state.hasError,
              errorMessage:
                  state.error?.localize(context) ?? context.s.errUnknown,
              onRefresh: _refresh,
              emptyIcon: Icons.badge_outlined,
              emptyMessage: context.s.employeesEmpty,
              itemBuilder: (_, employee, __) =>
                  _EmployeeTile(employee: employee),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final Employee employee;
  const _EmployeeTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          InitialAvatar(
            name: employee.name,
            foreground: colors.onTertiary,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.tertiary,
                Color.lerp(colors.tertiary, colors.primary, 0.5) ??
                    colors.tertiary,
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (employee.login != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    employee.login!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: context.s.createVisitTooltip,
            icon: Icon(Icons.add_circle_outline, color: colors.primary),
            onPressed: () => context.push(
              AppRoutes.createVisit,
              extra: {'employee': employee},
            ),
          ),
        ],
      ),
    );
  }
}
