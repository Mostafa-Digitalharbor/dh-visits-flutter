import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../bloc/employees_bloc.dart';
import '../data/models/employee.dart';

/// Manager-only screen: lists `res.users` in the Customer Visits groups.
/// Each row has a quick "+ visit" action that jumps to the create form
/// with this employee pre-selected.
class EmployeesListPage extends StatefulWidget {
  const EmployeesListPage({super.key});

  @override
  State<EmployeesListPage> createState() => _EmployeesListPageState();
}

class _EmployeesListPageState extends State<EmployeesListPage> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EmployeesBloc>().add(const EmployeesLoadRequested());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      context.read<EmployeesBloc>().add(EmployeesSearchChanged(v.trim()));
    });
  }

  Future<void> _refresh() async {
    context.read<EmployeesBloc>().add(const EmployeesLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.s.employeesSearchHint,
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<EmployeesBloc, EmployeesState>(
            builder: (context, state) {
              if (state.status == EmployeesStatus.failure &&
                  state.items.isEmpty) {
                return ErrorView(
                  message:
                      state.error?.localize(context) ?? context.s.errUnknown,
                  onRetry: _refresh,
                );
              }

              Widget body;
              if (state.status == EmployeesStatus.loading) {
                body = const SkeletonList(
                  key: ValueKey('skeleton'),
                  itemCount: 8,
                );
              } else if (state.items.isEmpty) {
                body = ScaleFadeIn(
                  key: const ValueKey('empty'),
                  child: EmptyView(
                    icon: Icons.badge_outlined,
                    message: context.s.employeesEmpty,
                  ),
                );
              } else {
                body = ListView.separated(
                  key: const ValueKey('list'),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => AnimatedListItem(
                    index: i,
                    child: _EmployeeTile(employee: state.items[i]),
                  ),
                );
              }

              return AppRefreshIndicator(
                onRefresh: _refresh,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: body,
                ),
              );
            },
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
    final initial =
        employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?';
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                color: colors.onTertiary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
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
              '/visits/create',
              extra: {'employee': employee},
            ),
          ),
        ],
      ),
    );
  }
}
