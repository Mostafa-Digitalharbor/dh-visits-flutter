import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/status_banner.dart';
import '../bloc/live_location_bloc.dart';

/// Reports that live location sharing has stopped, and why.
///
/// [LiveLocationBloc] emits an error on three paths — the server doesn't
/// support presence, the permission was refused or revoked mid-session, and
/// every failed ping — but nothing in the app rendered any of them. The
/// employee's radar pin silently went stale while they assumed they were
/// visible to their manager, which defeats the point of the feature.
///
/// Collapses to zero height while sharing is healthy so it never shifts layout.
class LiveLocationBanner extends StatelessWidget {
  const LiveLocationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveLocationBloc, LiveLocationState>(
      // Only rebuild when the *reported condition* changes, not on every
      // successful ping — this sits under the AppBar on every tab.
      buildWhen: (a, b) => a.error != b.error || a.enabled != b.enabled,
      builder: (context, state) {
        final error = state.error;
        if (error == null) return const SizedBox.shrink();
        return StatusBanner(
          color: Colors.orange.shade800,
          icon: Icons.location_off_rounded,
          message: switch (error.code) {
            // "Not supported" is an admin problem, not something the employee
            // can act on — say so plainly instead of asking them to fix it.
            ApiErrorCode.notSupported => context.s.liveLocationUnsupported,
            ApiErrorCode.locationPermission =>
              context.s.liveLocationPermissionOff,
            _ => context.s.liveLocationPingFailed,
          },
          action: error.code == ApiErrorCode.locationPermission
              ? TextButton(
                  onPressed: () => context
                      .read<LiveLocationBloc>()
                      .add(const LiveLocationStartRequested()),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(context.s.commonRetry),
                )
              : null,
        );
      },
    );
  }
}
