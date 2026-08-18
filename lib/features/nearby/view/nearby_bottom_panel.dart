import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/constants.dart';
import '../../../core/utils/app_date.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/nearby_bloc.dart';
import '../data/models/nearby_employee.dart';

class NearbyBottomPanel extends StatelessWidget {
  final NearbyState state;
  const NearbyBottomPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final tf = AppDate.timeWithSecondsFormat(context);
    final canEdit =
        context.watch<AuthBloc>().state.user?.canEditVisits ?? false;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.primaryContainer,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.business_rounded,
                    size: 18, color: context.colors.onPrimaryContainer),
              ),
              context.gapW(Insets.x2h),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.customer?.name ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      context.s.nearbyRadiusLabel(
                          state.radius.toStringAsFixed(0)),
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.lastRefresh != null)
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 13, color: context.colors.onSurfaceVariant),
                    context.gapW(Insets.x1),
                    Text(
                      tf.format(state.lastRefresh!),
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (canEdit) ...[
            context.gapH(Insets.x1h),
            _RadiusSlider(currentRadius: state.radius),
          ],
          context.gapH(Insets.x3),
          if (state.employees.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                      state.error != null
                          ? Icons.info_outline_rounded
                          : Icons.person_off_outlined,
                      size: 18,
                      color: context.colors.onSurfaceVariant),
                  context.gapW(Insets.x1h),
                  Expanded(
                    child: Text(
                      state.error != null
                          ? state.error!.localize(context)
                          : state.status == NearbyStatus.success
                              ? context.s.nearbyEmpty
                              : context.s.commonLoading,
                      style: TextStyle(
                          color: context.colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              // fixedH, not a raw 86: _EmployeeCard stacks three text lines,
              // which at the 1.25 text-scale cap need ~69dp against the 66dp
              // this leaves after padding. Growing the strip with the text
              // keeps the last line from clipping.
              height: context.fixedH(86),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.employees.length,
                separatorBuilder: (_, __) => context.gapW(Insets.x2),
                itemBuilder: (context, i) =>
                    _EmployeeCard(employee: state.employees[i]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Manager-only slider for the search radius. Uses local draft state during
/// the drag so the bloc only refetches when the user releases the thumb
/// (otherwise we'd spam `/nearby-employees` on every pixel of movement).
class _RadiusSlider extends StatefulWidget {
  final double currentRadius;
  const _RadiusSlider({required this.currentRadius});

  @override
  State<_RadiusSlider> createState() => _RadiusSliderState();
}

class _RadiusSliderState extends State<_RadiusSlider> {
  static const double _min = AppConstants.nearbyRadiusMinMeters;
  static const double _max = AppConstants.nearbyRadiusMaxMeters;

  double? _draft;

  @override
  Widget build(BuildContext context) {
    final value = (_draft ?? widget.currentRadius).clamp(_min, _max);
    return Row(
      children: [
        Icon(Icons.adjust_rounded,
            size: 16, color: context.colors.onSurfaceVariant),
        context.gapW(Insets.x1h),
        Text(
          context.s.unitMeters(value.toStringAsFixed(0)),
          style: context.text.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              min: _min,
              max: _max,
              value: value,
              divisions: ((_max - _min) ~/ 5),
              label:
                  context.s.unitMeters(value.toStringAsFixed(0)),
              onChanged: (v) => setState(() => _draft = v),
              onChangeEnd: (v) {
                setState(() => _draft = null);
                context.read<NearbyBloc>().add(NearbyRadiusChanged(v));
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final NearbyEmployee employee;
  const _EmployeeCard({required this.employee});

  @override
  Widget build(BuildContext context) {
    final tf = AppDate.timeWithSecondsFormat(context);
    final initial =
        InitialAvatar.initialOf(employee.name);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.errorContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          context.gapW(Insets.x2h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  employee.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  context.s.unitMeters(
                      employee.distanceMeters.toStringAsFixed(1)),
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onErrorContainer,
                  ),
                ),
                if (employee.lastUpdate != null)
                  Text(
                    tf.format(employee.lastUpdate!),
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.onErrorContainer
                          .withValues(alpha: 0.8),
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

